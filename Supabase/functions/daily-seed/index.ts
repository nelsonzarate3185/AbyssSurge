/**
 * daily-seed — devuelve (y materializa) la seed compartida del día.
 *
 * El cliente nunca inventa la seed: la pide acá y reproduce el nivel
 * localmente con el mismo algoritmo. Ver GAME_MECHANICS.md §8.
 */
import { adminClient, requireUser } from "../_shared/supabase.ts";
import { corsHeaders, fail, json } from "../_shared/cors.ts";
import { dailySeed, utcToday } from "../_shared/seed.ts";

/** Modificadores rotativos por día de la semana. [TUNE] */
const MODIFIER_ROTATION = [
  { name: "still_water", oxygenMultiplier: 1.15, lootMultiplier: 1.0 },
  { name: "riptide", oxygenMultiplier: 0.85, lootMultiplier: 1.4 },
  { name: "blackout", visibility: 0.5, lootMultiplier: 1.6 },
  { name: "bloom", awakenedDensity: 1.5, lootMultiplier: 1.3 },
  { name: "cold_current", descentSpeed: 1.25, lootMultiplier: 1.1 },
  { name: "quota_day", lootMultiplier: 2.0, corruptionMultiplier: 1.5 },
  { name: "clear", lootMultiplier: 1.0 },
] as const;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    await requireUser(req);
  } catch (e) {
    return fail((e as Error).message, 401);
  }

  const date = utcToday();
  const db = adminClient();

  const { data: existing } = await db
    .from("daily_seeds")
    .select("seed_date, seed, modifiers")
    .eq("seed_date", date)
    .maybeSingle();

  if (existing) {
    return json({ date: existing.seed_date, seed: existing.seed, modifiers: existing.modifiers });
  }

  const seed = await dailySeed(date);
  const modifiers = MODIFIER_ROTATION[new Date(`${date}T00:00:00Z`).getUTCDay()];

  const { error } = await db
    .from("daily_seeds")
    .upsert({ seed_date: date, seed, modifiers }, { onConflict: "seed_date" });

  if (error) return fail(error.message, 500);

  return json({ date, seed, modifiers });
});
