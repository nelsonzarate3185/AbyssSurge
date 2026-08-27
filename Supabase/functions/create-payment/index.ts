/**
 * create-payment — abre una compra de gemas y devuelve el link de pago.
 *
 * El precio NO viene del cliente: se lee de `gem_products`. Lo único que el
 * jugador elige es el SKU.
 */
import { adminClient, requireUser } from "../_shared/supabase.ts";
import { corsHeaders, fail, json } from "../_shared/cors.ts";
import { createPreference } from "../_shared/mercadopago.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail("method not allowed", 405);

  let user: { id: string; email?: string };
  try {
    user = await requireUser(req);
  } catch (e) {
    return fail((e as Error).message, 401);
  }

  const body = await req.json().catch(() => null) as { sku?: string } | null;
  const sku = body?.sku;
  if (typeof sku !== "string" || !sku) return fail("invalid sku");

  const db = adminClient();

  const { data: product } = await db
    .from("gem_products")
    .select("sku, gems, price_cents, currency, currency_exponent, bonus_pct, is_active")
    .eq("sku", sku)
    .maybeSingle();

  if (!product) return fail("product not found", 404);
  if (!product.is_active) return fail("product is not available", 410);

  // MercadoPago Paraguay solo cobra en guaraníes. Los SKUs en USD son para
  // App Store y Google Play, que tienen su propio flujo.
  if (product.currency !== "PYG") {
    return fail(`product ${sku} is priced in ${product.currency}; MercadoPago PY requires PYG`, 422);
  }

  const { data: hunter } = await db
    .from("hunters").select("id").eq("id", user.id).maybeSingle();
  if (!hunter) return fail("hunter not found — call bootstrap_hunter first", 404);

  const gemsGranted = product.gems + Math.floor(product.gems * product.bonus_pct / 100);

  // La fila se crea ANTES de hablar con MercadoPago: su id es el
  // external_reference con el que después el webhook encuentra la compra.
  const { data: purchase, error: insertError } = await db
    .from("purchases")
    .insert({
      hunter_id: user.id,
      sku: product.sku,
      gems_granted: gemsGranted,
      price_cents: product.price_cents,
      currency: product.currency,
      provider: "mercadopago",
      status: "pending",
    })
    .select("id")
    .single();

  if (insertError) return fail(insertError.message, 500);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const unitPrice = product.price_cents / Math.pow(10, product.currency_exponent);

  let preference;
  try {
    preference = await createPreference({
      purchaseId: purchase.id,
      title: `${gemsGranted} gemas — Abyss Surge`,
      quantity: 1,
      unitPrice,
      currencyId: product.currency,
      payerEmail: user.email,
      notificationUrl: `${supabaseUrl}/functions/v1/payment-webhook`,
      backUrl: Deno.env.get("PAYMENT_RETURN_URL") ?? "abysssurge://payment-return",
    });
  } catch (e) {
    // La preferencia no se creó: la compra nunca va a recibir webhook.
    await db.from("purchases")
      .update({ status: "failed", settled_at: new Date().toISOString() })
      .eq("id", purchase.id);
    return fail((e as Error).message, 502);
  }

  await db.from("purchases")
    .update({ preference_id: preference.id })
    .eq("id", purchase.id);

  return json({
    purchaseId: purchase.id,
    preferenceId: preference.id,
    gemsGranted,
    amount: unitPrice,
    currency: product.currency,
    // En sandbox hay que abrir sandbox_init_point.
    checkoutUrl: preference.init_point,
    sandboxCheckoutUrl: preference.sandbox_init_point,
  });
});
