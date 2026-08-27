/**
 * Seed diaria determinista. El cliente Unity debe reproducir esta misma
 * función para generar el mismo nivel — ver GAME_MECHANICS.md §8.
 */
export async function dailySeed(date: string): Promise<string> {
  const salt = Deno.env.get("DAILY_SEED_SALT") ?? "change-me";
  const bytes = new TextEncoder().encode(`${date}:${salt}`);
  const digest = await crypto.subtle.digest("SHA-256", bytes);

  return Array.from(new Uint8Array(digest))
    .slice(0, 16)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function utcToday(): string {
  return new Date().toISOString().slice(0, 10);
}
