/**
 * complete-dungeon-run — cierra un intento y acredita recompensas.
 *
 * El cliente reporta qué pasó; acá se decide si es creíble. La acreditación
 * en sí la hace `award_dungeon_run()` en una sola transacción.
 */
import { adminClient, requireUser } from "../_shared/supabase.ts";
import { corsHeaders, fail, json } from "../_shared/cors.ts";

type Outcome = "cleared" | "failed" | "abandoned";
const OUTCOMES: readonly Outcome[] = ["cleared", "failed", "abandoned"];

/**
 * Un combate dura 30–60 s (PDF §7). 20 s es el piso creíble por encuentro,
 * con margen para un jugador muy sobreleveleado. [TUNE]
 */
const MIN_MS_PER_ENCOUNTER = 20_000;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail("method not allowed", 405);

  let user: { id: string };
  try {
    user = await requireUser(req);
  } catch (e) {
    return fail((e as Error).message, 401);
  }

  const body = await req.json().catch(() => null) as {
    sessionId?: string;
    floorsCleared?: number;
    bossDefeated?: boolean;
    outcome?: string;
    durationMs?: number;
  } | null;

  const sessionId = body?.sessionId;
  const floorsCleared = Math.floor(Number(body?.floorsCleared));
  const bossDefeated = body?.bossDefeated === true;
  const outcome = body?.outcome as Outcome;
  const durationMs = Math.floor(Number(body?.durationMs));

  if (typeof sessionId !== "string" || !sessionId) return fail("invalid sessionId");
  if (!Number.isFinite(floorsCleared) || floorsCleared < 0) return fail("invalid floorsCleared");
  if (!Number.isFinite(durationMs) || durationMs <= 0) return fail("invalid durationMs");
  if (!OUTCOMES.includes(outcome)) return fail("invalid outcome");

  const db = adminClient();

  const { data: session } = await db
    .from("dungeon_sessions")
    .select("id, hunter_id, dungeon_id, started_at, expires_at, consumed_at")
    .eq("id", sessionId)
    .maybeSingle();

  if (!session) return fail("session not found", 404);

  // La sesión es de quien la abrió. Sin esto, cualquiera cierra la de otro.
  if (session.hunter_id !== user.id) return fail("session belongs to another hunter", 403);
  if (session.consumed_at) return fail("session already consumed", 409);

  const { data: dungeon } = await db
    .from("dungeons")
    .select("floors, has_boss")
    .eq("id", session.dungeon_id)
    .single();

  // ── Coherencia interna del reporte.
  if (floorsCleared > dungeon.floors) return fail("floorsCleared exceeds dungeon floors", 422);
  if (bossDefeated && !dungeon.has_boss) return fail("dungeon has no boss", 422);
  if (bossDefeated && floorsCleared < dungeon.floors) {
    return fail("boss defeated without clearing all floors", 422);
  }
  if (outcome === "cleared" && dungeon.has_boss && !bossDefeated) {
    return fail("cleared requires defeating the boss", 422);
  }

  // ── Tiempo: ni instantáneo ni más largo que la ventana de la sesión.
  const encounters = floorsCleared + (bossDefeated ? 1 : 0);
  if (durationMs < encounters * MIN_MS_PER_ENCOUNTER) {
    return fail("duration too short for the reported progress", 422);
  }

  const elapsedMs = Date.now() - Date.parse(session.started_at);
  const windowMs = Date.parse(session.expires_at) - Date.parse(session.started_at);
  if (durationMs > windowMs || durationMs > elapsedMs + 5_000) {
    return fail("duration inconsistent with session window", 422);
  }

  // ── Acreditar. Una transacción: consume sesión, registra, suma, promueve.
  const { data: run, error } = await db.rpc("award_dungeon_run", {
    p_session_id: sessionId,
    p_floors_cleared: floorsCleared,
    p_boss_defeated: bossDefeated,
    p_outcome: outcome,
    p_duration_ms: durationMs,
  });

  if (error) {
    const status = error.message.includes("expired") ? 410
      : error.message.includes("already consumed") ? 409
      : 500;
    return fail(error.message, status);
  }

  const { data: hunter } = await db
    .from("hunters")
    .select("rank, exp, gold, essence, story_act")
    .eq("id", user.id)
    .single();

  return json({
    runId: run.id,
    outcome: run.outcome,
    expAwarded: run.exp_awarded,
    goldAwarded: run.gold_awarded,
    essenceAwarded: run.essence_awarded,
    // El rango puede haber subido dentro de award_dungeon_run.
    hunter,
  });
});
