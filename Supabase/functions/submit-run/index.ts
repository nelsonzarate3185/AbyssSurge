/**
 * submit-run — única vía para acreditar el resultado de un descenso.
 *
 * El cliente es hostil por definición: acá se valida todo lo que el
 * jugador podría inflar (profundidad, núcleos, duración) antes de tocar
 * la economía. Ver GAME_MECHANICS.md §9.
 */
import { adminClient, requireUser } from "../_shared/supabase.ts";
import { corsHeaders, fail, json } from "../_shared/cors.ts";
import { dailySeed } from "../_shared/seed.ts";

type Outcome = "ascended" | "drowned" | "crushed" | "abandoned";
type SurgerClass = "diver" | "ballast" | "needle" | "scavenger";

interface RunPayload {
  seed: string;
  seedDate?: string;
  class: SurgerClass;
  depthMeters: number;
  coresCollected: number;
  scrapCollected: number;
  durationMs: number;
  outcome: Outcome;
  startedAt: string;
}

/** Velocidad máxima de descenso sostenida, m/s. [TUNE] */
const MAX_DESCENT_MPS = 34;
/** Capacidad base del colector + 12 por nivel. [TUNE] */
const COLLECTOR_BASE = 20;
const COLLECTOR_PER_LEVEL = 12;

const CLASSES: readonly SurgerClass[] = ["diver", "ballast", "needle", "scavenger"];
const OUTCOMES: readonly Outcome[] = ["ascended", "drowned", "crushed", "abandoned"];

function parse(body: unknown): RunPayload {
  const b = body as Partial<RunPayload>;
  const num = (v: unknown, name: string): number => {
    if (typeof v !== "number" || !Number.isFinite(v) || v < 0) {
      throw new Error(`invalid ${name}`);
    }
    return Math.floor(v);
  };

  if (typeof b.seed !== "string" || b.seed.length < 8) throw new Error("invalid seed");
  if (!CLASSES.includes(b.class as SurgerClass)) throw new Error("invalid class");
  if (!OUTCOMES.includes(b.outcome as Outcome)) throw new Error("invalid outcome");
  if (typeof b.startedAt !== "string" || Number.isNaN(Date.parse(b.startedAt))) {
    throw new Error("invalid startedAt");
  }

  return {
    seed: b.seed,
    seedDate: typeof b.seedDate === "string" ? b.seedDate : undefined,
    class: b.class as SurgerClass,
    depthMeters: num(b.depthMeters, "depthMeters"),
    coresCollected: num(b.coresCollected, "coresCollected"),
    scrapCollected: num(b.scrapCollected, "scrapCollected"),
    durationMs: Math.max(1, num(b.durationMs, "durationMs")),
    outcome: b.outcome as Outcome,
    startedAt: b.startedAt,
  };
}

/** Corrupción ganada: 1 cada 300 m bajo 600 m. [TUNE] */
function corruptionGain(depthMeters: number): number {
  return depthMeters <= 600 ? 0 : Math.floor((depthMeters - 600) / 300);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail("method not allowed", 405);

  let user: { id: string };
  let run: RunPayload;
  try {
    user = await requireUser(req);
    run = parse(await req.json());
  } catch (e) {
    return fail((e as Error).message, 401);
  }

  const db = adminClient();

  // ── 1. Reloj: la run no puede venir del futuro ni de hace una era.
  const skew = Number(Deno.env.get("RUN_CLOCK_SKEW_SECONDS") ?? 120) * 1000;
  const started = Date.parse(run.startedAt);
  const drift = Date.now() - (started + run.durationMs);
  if (drift < -skew || drift > 6 * 60 * 60 * 1000) {
    return fail("run timestamps out of range", 422);
  }

  // ── 2. Física: profundidad alcanzable en el tiempo declarado.
  const maxDepth = (run.durationMs / 1000) * MAX_DESCENT_MPS;
  if (run.depthMeters > maxDepth) {
    return fail("depth not reachable in declared duration", 422);
  }

  // ── 3. Capacidad: núcleos ≤ colector equipado.
  const { data: collector } = await db
    .from("board_upgrades")
    .select("level")
    .eq("player_id", user.id)
    .eq("slot", "collector")
    .maybeSingle();

  const capacity = COLLECTOR_BASE + COLLECTOR_PER_LEVEL * (collector?.level ?? 0);
  if (run.coresCollected > capacity) {
    return fail("cores exceed collector capacity", 422);
  }

  // ── 4. Seed diaria: tiene que ser la del servidor, no la que mandó el cliente.
  if (run.seedDate) {
    const expected = await dailySeed(run.seedDate);
    if (expected !== run.seed) return fail("seed mismatch for daily run", 422);
  }

  // ── 5. Solo el ascenso acredita botín (GAME_MECHANICS.md §2).
  const credited = run.outcome === "ascended";
  const gain = corruptionGain(run.depthMeters);

  const { data: inserted, error: insertError } = await db
    .from("runs")
    .insert({
      player_id: user.id,
      seed: run.seed,
      seed_date: run.seedDate ?? null,
      class: run.class,
      depth_meters: run.depthMeters,
      cores_collected: run.coresCollected,
      scrap_collected: run.scrapCollected,
      duration_ms: run.durationMs,
      outcome: run.outcome,
      credited,
      corruption_gain: gain,
      started_at: run.startedAt,
    })
    .select("id")
    .single();

  if (insertError) {
    // 23505 = unique_violation → ya jugó la seed diaria de hoy.
    const status = insertError.code === "23505" ? 409 : 500;
    return fail(insertError.message, status);
  }

  // ── 6. Acreditación / naufragio.
  if (credited) {
    const { error } = await db.rpc("credit_run", { p_run_id: inserted.id });
    if (error) return fail(error.message, 500);
  } else if (run.coresCollected > 0) {
    await db.from("wrecks").insert({
      run_id: inserted.id,
      player_id: user.id,
      seed: run.seed,
      depth_meters: run.depthMeters,
      cores_lost: run.coresCollected,
    });
  }

  return json({
    runId: inserted.id,
    credited,
    coresAwarded: credited ? run.coresCollected : 0,
    scrapAwarded: credited ? run.scrapCollected : 0,
    corruptionGained: credited ? gain : 0,
    wreckLeft: !credited && run.coresCollected > 0,
  });
});
