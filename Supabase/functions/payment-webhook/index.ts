/**
 * payment-webhook — recibe las notificaciones de MercadoPago y acredita.
 *
 * Reglas que gobiernan este archivo:
 *
 * 1. NUNCA confiar en el body. La notificación solo trae un id; el estado
 *    real se consulta contra la API de MercadoPago con nuestro token.
 * 2. Validar la firma antes de tocar nada.
 * 3. Responder 200 en todo lo que no sea un fallo transitorio nuestro.
 *    MercadoPago reintenta ante cualquier no-2xx, así que devolver 500 por
 *    una notificación que nunca vamos a poder procesar genera reintentos
 *    infinitos.
 */
import { adminClient } from "../_shared/supabase.ts";
import { fail, json } from "../_shared/cors.ts";
import { fetchPayment, mapStatus, verifyWebhookSignature } from "../_shared/mercadopago.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return fail("method not allowed", 405);

  const url = new URL(req.url);
  // MercadoPago manda el id en el query string; es el que entra al manifiesto
  // de la firma. El body trae el mismo valor pero no es el que se firma.
  const dataId = url.searchParams.get("data.id") ?? url.searchParams.get("id");
  const topic = url.searchParams.get("type") ?? url.searchParams.get("topic");

  let valid: boolean;
  try {
    valid = await verifyWebhookSignature(req, dataId);
  } catch (e) {
    // Falta el secret: es un problema de configuración nuestro, no de la
    // notificación. 500 para que MercadoPago reintente cuando lo arreglemos.
    console.error("[webhook] config error:", (e as Error).message);
    return fail("webhook not configured", 500);
  }

  if (!valid) {
    console.warn("[webhook] firma inválida", { dataId, topic });
    return fail("invalid signature", 401);
  }

  const body = await req.json().catch(() => ({})) as Record<string, unknown>;
  const type = topic ?? body.type;

  // Solo interesan los pagos. Merchant orders y demás se aceptan y se ignoran.
  if (type !== "payment") {
    return json({ ignored: true, type });
  }

  const paymentId = dataId ?? String((body.data as { id?: unknown })?.id ?? "");
  if (!paymentId) return json({ ignored: true, reason: "no payment id" });

  let payment;
  try {
    payment = await fetchPayment(paymentId);
  } catch (e) {
    // La API no respondió. Esto sí es transitorio: que reintente.
    console.error("[webhook] lookup falló:", (e as Error).message);
    return fail("payment lookup failed", 502);
  }

  const purchaseId = payment.external_reference;
  if (!purchaseId) {
    console.warn("[webhook] pago sin external_reference", paymentId);
    return json({ ignored: true, reason: "no external_reference" });
  }

  const db = adminClient();

  const { data: purchase } = await db
    .from("purchases")
    .select("id, hunter_id, status, price_cents, currency, gems_granted")
    .eq("id", purchaseId)
    .maybeSingle();

  if (!purchase) {
    console.warn("[webhook] compra inexistente", purchaseId);
    return json({ ignored: true, reason: "purchase not found" });
  }

  const status = mapStatus(payment.status);

  // Todavía en proceso: se registra el intento y se espera otra notificación.
  if (status === "pending") {
    return json({ purchaseId, status: payment.status, pending: true });
  }

  if (status === "paid") {
    // El monto tiene que coincidir con lo que abrimos. Si no coincide,
    // alguien pagó otra cosa: no se acredita y queda para revisión manual.
    const expected = purchase.price_cents /
      Math.pow(10, purchase.currency === "PYG" ? 0 : 2);

    if (payment.transaction_amount !== expected ||
        payment.currency_id !== purchase.currency) {
      console.error("[webhook] monto no coincide", {
        purchaseId,
        expected,
        got: payment.transaction_amount,
        currency: payment.currency_id,
      });
      return json({ purchaseId, mismatch: true }, 200);
    }

    const { error } = await db.rpc("credit_purchase", {
      p_purchase_id: purchaseId,
      p_provider_ref: String(payment.id),
      p_raw: payment,
    });

    if (error) {
      console.error("[webhook] credit_purchase falló:", error.message);
      return fail(error.message, 500);
    }

    return json({ purchaseId, credited: true, gems: purchase.gems_granted });
  }

  const { error } = await db.rpc("fail_purchase", {
    p_purchase_id: purchaseId,
    p_status: status,
    p_provider_ref: String(payment.id),
    p_raw: payment,
  });

  if (error) {
    console.error("[webhook] fail_purchase falló:", error.message);
    return fail(error.message, 500);
  }

  return json({ purchaseId, status });
});
