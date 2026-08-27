/**
 * enter-dungeon — abre un intento de mazmorra.
 *
 * Acá se cobra la energía. Si se cobrara al terminar, un cliente modificado
 * podría jugar gratis; si no se cobrara nada al entrar, el jugador podría
 * gastar 60 s y comerse un rechazo por falta de energía.
 */
import { adminClient, requireUser } from "../_shared/supabase.ts";
import { corsHeaders, fail, json } from "../_shared/cors.ts";

type Difficulty = "normal" | "hard" | "impossible";

const DIFFICULTIES: readonly Difficulty[] = ["normal", "hard", "impossible"];

/** Ventana para completar la mazmorra. El combate dura 30–60 s (PDF §7). */
const SESSION_TTL_MINUTES = 30;

/** Orden de rangos: el índice es la comparación. Igual que el enum en SQL. */
const RANKS = ["E", "D", "C", "B", "A", "S", "SS", "SSS"] as const;
const rankIndex = (r: string) => RANKS.indexOf(r as typeof RANKS[number]);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail("method not allowed", 405);

  let user: { id: string };
  try {
    user = await requireUser(req);
  } catch (e) {
    return fail((e as Error).message, 401);
  }

  const body = await req.json().catch(() => null) as
    | { dungeonId?: string; difficulty?: string }
    | null;

  const dungeonId = body?.dungeonId;
  const difficulty = (body?.difficulty ?? "normal") as Difficulty;

  if (typeof dungeonId !== "string" || !dungeonId) return fail("invalid dungeonId");
  if (!DIFFICULTIES.includes(difficulty)) return fail("invalid difficulty");

  const db = adminClient();

  const [{ data: hunter }, { data: dungeon }, { data: mod }] = await Promise.all([
    db.from("hunters").select("id, rank, class").eq("id", user.id).maybeSingle(),
    db.from("dungeons").select("id, type, min_rank, energy_cost").eq("id", dungeonId).maybeSingle(),
    db.from("difficulty_modifiers").select("difficulty, min_rank").eq("difficulty", difficulty)
      .maybeSingle(),
  ]);

  if (!hunter) return fail("hunter not found — call bootstrap_hunter first", 404);
  if (!dungeon) return fail("dungeon not found", 404);
  if (!mod) return fail("difficulty not found", 404);

  // ── Rango: el de la mazmorra y el de la dificultad.
  if (rankIndex(hunter.rank) < rankIndex(dungeon.min_rank)) {
    return fail(`rank ${dungeon.min_rank} required for this dungeon`, 403);
  }
  if (rankIndex(hunter.rank) < rankIndex(mod.min_rank)) {
    return fail(`rank ${mod.min_rank} required for ${difficulty}`, 403);
  }

  // ── Las mazmorras de clan requieren pertenecer a uno.
  if (dungeon.type === "clan") {
    const { data: membership } = await db
      .from("clan_members").select("clan_id").eq("hunter_id", user.id).maybeSingle();
    if (!membership) return fail("clan membership required", 403);
  }

  // ── Cobrar la energía. Falla con P0001 si no alcanza.
  const { data: remaining, error: energyError } = await db
    .rpc("spend_energy", { p_hunter_id: user.id, p_cost: dungeon.energy_cost });

  if (energyError) {
    const status = energyError.message.includes("insufficient energy") ? 402 : 500;
    return fail(energyError.message, status);
  }

  // ── Abrir la sesión. El índice único rechaza una segunda sesión abierta.
  const { data: session, error: sessionError } = await db
    .from("dungeon_sessions")
    .insert({
      hunter_id: user.id,
      dungeon_id: dungeonId,
      difficulty,
      rank_at_entry: hunter.rank,
      energy_spent: dungeon.energy_cost,
      expires_at: new Date(Date.now() + SESSION_TTL_MINUTES * 60_000).toISOString(),
    })
    .select("id, started_at, expires_at")
    .single();

  if (sessionError) {
    // 23505 = ya hay una sesión abierta. La energía ya se cobró: hay que
    // devolverla, si no el jugador la pierde por un doble tap.
    if (sessionError.code === "23505") {
      await db.rpc("refund_energy", { p_hunter_id: user.id, p_amount: dungeon.energy_cost });
      return fail("a dungeon session is already open", 409);
    }
    return fail(sessionError.message, 500);
  }

  return json({
    sessionId: session.id,
    dungeonId,
    difficulty,
    rankAtEntry: hunter.rank,
    energySpent: dungeon.energy_cost,
    energyRemaining: remaining,
    startedAt: session.started_at,
    expiresAt: session.expires_at,
  });
});
