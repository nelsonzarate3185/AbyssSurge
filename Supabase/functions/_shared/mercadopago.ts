/**
 * Helpers de MercadoPago Paraguay.
 *
 * Referencia de la validación de firma:
 * https://www.mercadopago.com.py/developers/es/docs/your-integrations/notifications/webhooks
 */

const MP_API = "https://api.mercadopago.com";

function accessToken(): string {
  const token = Deno.env.get("MERCADOPAGO_ACCESS_TOKEN");
  if (!token) throw new Error("MERCADOPAGO_ACCESS_TOKEN not configured");
  return token;
}

/**
 * Valida el `x-signature` de un webhook.
 *
 * El header viene como `ts=1742505638683,v1=<hex>`. El manifiesto que se
 * firma es, textual:
 *
 *     id:<data.id>;request-id:<x-request-id>;ts:<ts>;
 *
 * Si alguno de los tres no está en la notificación, se omite ese tramo
 * entero del manifiesto (no se deja vacío).
 *
 * `data.id` sale del query string de la URL del webhook, no del body: son
 * el mismo valor pero MercadoPago firma el del query string.
 */
export async function verifyWebhookSignature(
  req: Request,
  dataId: string | null,
): Promise<boolean> {
  const secret = Deno.env.get("MERCADOPAGO_WEBHOOK_SECRET");
  if (!secret) throw new Error("MERCADOPAGO_WEBHOOK_SECRET not configured");

  const signature = req.headers.get("x-signature");
  const requestId = req.headers.get("x-request-id");
  if (!signature) return false;

  const parts = new Map<string, string>();
  for (const chunk of signature.split(",")) {
    const [key, value] = chunk.split("=", 2);
    if (key && value) parts.set(key.trim(), value.trim());
  }

  const ts = parts.get("ts");
  const v1 = parts.get("v1");
  if (!ts || !v1) return false;

  // Los ids alfanuméricos se firman en minúscula.
  const normalizedId = dataId && /[a-zA-Z]/.test(dataId) ? dataId.toLowerCase() : dataId;

  let manifest = "";
  if (normalizedId) manifest += `id:${normalizedId};`;
  if (requestId) manifest += `request-id:${requestId};`;
  manifest += `ts:${ts};`;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(manifest));
  const expected = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return timingSafeEqual(expected, v1);
}

/** Comparación en tiempo constante. Un `===` filtra información por timing. */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export interface MpPayment {
  id: number;
  status: string;
  status_detail: string;
  external_reference: string | null;
  transaction_amount: number;
  currency_id: string;
}

/** Trae el pago desde la API. Nunca confiar en el body del webhook. */
export async function fetchPayment(paymentId: string): Promise<MpPayment> {
  const res = await fetch(`${MP_API}/v1/payments/${paymentId}`, {
    headers: { Authorization: `Bearer ${accessToken()}` },
  });

  if (!res.ok) {
    throw new Error(`mercadopago payment lookup failed: ${res.status} ${await res.text()}`);
  }
  return await res.json() as MpPayment;
}

export interface PreferenceInput {
  purchaseId: string;
  title: string;
  quantity: number;
  unitPrice: number;
  currencyId: string;
  payerEmail?: string;
  notificationUrl: string;
  backUrl: string;
}

export interface MpPreference {
  id: string;
  init_point: string;
  sandbox_init_point: string;
}

/**
 * Crea una preferencia de Checkout Pro.
 *
 * `external_reference` lleva el id de nuestra fila en `purchases`: es lo que
 * permite matchear el webhook contra la compra sin confiar en nada más.
 */
export async function createPreference(input: PreferenceInput): Promise<MpPreference> {
  const res = await fetch(`${MP_API}/checkout/preferences`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken()}`,
      "Content-Type": "application/json",
      // Evita crear dos preferencias si el cliente reintenta.
      "X-Idempotency-Key": input.purchaseId,
    },
    body: JSON.stringify({
      items: [{
        id: input.purchaseId,
        title: input.title,
        quantity: input.quantity,
        unit_price: input.unitPrice,
        currency_id: input.currencyId,
      }],
      external_reference: input.purchaseId,
      notification_url: input.notificationUrl,
      payer: input.payerEmail ? { email: input.payerEmail } : undefined,
      back_urls: {
        success: `${input.backUrl}?status=success`,
        pending: `${input.backUrl}?status=pending`,
        failure: `${input.backUrl}?status=failure`,
      },
      auto_return: "approved",
      statement_descriptor: "ABYSSSURGE",
    }),
  });

  if (!res.ok) {
    throw new Error(`mercadopago preference failed: ${res.status} ${await res.text()}`);
  }
  return await res.json() as MpPreference;
}

/** Mapea el estado de MercadoPago al enum `purchase_status` del schema. */
export function mapStatus(mpStatus: string): "paid" | "failed" | "cancelled" | "refunded" | "pending" {
  switch (mpStatus) {
    case "approved":
      return "paid";
    case "rejected":
      return "failed";
    case "cancelled":
      return "cancelled";
    case "refunded":
    case "charged_back":
      return "refunded";
    // 'pending', 'authorized', 'in_process', 'in_mediation' siguen abiertos.
    default:
      return "pending";
  }
}
