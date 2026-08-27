import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

/** Cliente con service_role. Nunca lo expongas al cliente Unity. */
export function adminClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

/** Resuelve el jugador a partir del Bearer token de la request. */
export async function requireUser(req: Request): Promise<{ id: string }> {
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) throw new Error("missing bearer token");

  const { data, error } = await adminClient().auth.getUser(auth.slice(7));
  if (error || !data.user) throw new Error("invalid token");

  return { id: data.user.id };
}
