-- 007_reference_data.sql
-- Catálogo del juego. Va en una MIGRATION, no en seeds/, porque estos datos
-- hacen falta en producción: sin ellos no se puede crear un cazador.
-- seeds/seed.sql queda solo para usuarios de prueba locales.
--
-- Todo con upsert: la migration es re-ejecutable sin romper nada.

-- ─────────────────────────────────────────────────────────────
-- Constantes de balance
-- ─────────────────────────────────────────────────────────────

insert into game_settings (key, value, description) values
  ('energy_max',            '50',  'Energía máxima acumulable'),
  ('energy_regen_minutes',  '6',   'Minutos por punto de energía (50 pts = 5 h)'),
  ('clan_war_interval_days','3',   'Cada cuántos días arranca una Clan War (PDF §6)'),
  ('clan_max_members',      '50',  'Tope de miembros por clan (PDF §6)')
on conflict (key) do update set value = excluded.value,
                                description = excluded.description;

-- ─────────────────────────────────────────────────────────────
-- Clases — valores EXACTOS del PDF §3. No tunear sin actualizar el PDF.
-- ─────────────────────────────────────────────────────────────

insert into class_archetypes (class, label, base_hp, base_atk, base_def, base_vel, strength, weakness) values
  ('dark_slayer',   'Dark Slayer',   100, 12, 4,  9,  'Daño extremo, velocidad rápida',   'Muy frágil'),
  ('phantom_guard', 'Phantom Guard', 140, 8,  8,  5,  'Durabilidad extrema',              'Daño lento'),
  ('abyss_mage',    'Abyss Mage',    90,  9,  5,  10, 'AoE devastador, maná ilimitado',   'Muy frágil'),
  ('beast_hunter',  'Beast Hunter',  110, 11, 6,  8,  'Equilibrado, escalable',           'Versátil')
on conflict (class) do update set
  base_hp = excluded.base_hp, base_atk = excluded.base_atk,
  base_def = excluded.base_def, base_vel = excluded.base_vel,
  strength = excluded.strength, weakness = excluded.weakness;

-- ─────────────────────────────────────────────────────────────
-- Rangos E → SSS
-- El PDF dice que las stats suben, no cuánto. Estos números son [TUNE].
-- ─────────────────────────────────────────────────────────────

insert into rank_tiers (rank, tier, exp_required, stat_multiplier, aura_scale, aura_darkness) values
  ('E',   1,      0, 1.00, 1.00, 0.00),
  ('D',   2,   1000, 1.25, 1.15, 0.10),
  ('C',   3,   3500, 1.55, 1.30, 0.22),
  ('B',   4,   9000, 1.90, 1.50, 0.36),
  ('A',   5,  20000, 2.35, 1.75, 0.52),
  ('S',   6,  45000, 2.90, 2.00, 0.68),
  ('SS',  7, 100000, 3.60, 2.35, 0.85),
  ('SSS', 8, 250000, 4.50, 2.80, 1.00)
on conflict (rank) do update set
  exp_required = excluded.exp_required, stat_multiplier = excluded.stat_multiplier,
  aura_scale = excluded.aura_scale, aura_darkness = excluded.aura_darkness;

-- ─────────────────────────────────────────────────────────────
-- Dificultades (PDF §6)
-- ─────────────────────────────────────────────────────────────

insert into difficulty_modifiers (difficulty, enemy_multiplier, reward_multiplier, min_rank) values
  ('normal',     1.00, 1.00, 'E'),
  ('hard',       1.60, 1.80, 'C'),
  ('impossible', 2.75, 3.50, 'A')
on conflict (difficulty) do update set
  enemy_multiplier = excluded.enemy_multiplier,
  reward_multiplier = excluded.reward_multiplier,
  min_rank = excluded.min_rank;

-- ─────────────────────────────────────────────────────────────
-- Poderes
--
-- La cadena del Dark Slayer es la del PDF §6, textual.
-- Las otras tres clases tienen SOLO el tier 1, inventado para que
-- bootstrap_hunter() funcione. Sus cadenas completas están pendientes
-- de diseño — ver CHARACTER_DESIGN.md.
-- ─────────────────────────────────────────────────────────────

insert into powers (id, class, name, kind, category, tier, evolves_from,
                    damage_multiplier, is_aoe, is_crit, is_summon,
                    essence_cost, gold_cost, challenge_id, min_rank) values

  -- Dark Slayer — cadena completa del PDF
  ('ds_golpe_sombra',      'dark_slayer', 'Golpe Sombra',         'active', 'magic',   1, null,
   1.00, false, false, false,     0,     0, null,                  'E'),
  ('ds_cortadura_abismo',  'dark_slayer', 'Cortadura Abismo',     'active', 'magic',   2, 'ds_golpe_sombra',
   1.80, false, true,  false,   150,  2000, 'challenge_abyss_cut', 'D'),
  ('ds_tornada_oscura',    'dark_slayer', 'Tornada Oscura',       'active', 'magic',   3, 'ds_cortadura_abismo',
   2.50, true,  true,  false,   600, 12000, 'challenge_dark_storm','B'),
  ('ds_invocacion_espectros','dark_slayer','Invocación Espectros','active', 'summon',  4, 'ds_tornada_oscura',
   0.00, false, false, true,   2000, 45000, 'challenge_spectres',  'S'),

  -- Tier 1 de las otras clases — PLACEHOLDER, pendiente de diseño
  ('pg_muro_espectral',    'phantom_guard','Muro Espectral',      'active', 'defense', 1, null,
   1.00, false, false, false,     0,     0, null,                  'E'),
  ('am_pulso_abismal',     'abyss_mage',   'Pulso Abismal',       'active', 'magic',   1, null,
   1.00, true,  false, false,     0,     0, null,                  'E'),
  ('bh_marca_de_caza',     'beast_hunter', 'Marca de Caza',       'active', 'control', 1, null,
   1.00, false, false, false,     0,     0, null,                  'E')

on conflict (id) do update set
  name = excluded.name, damage_multiplier = excluded.damage_multiplier,
  essence_cost = excluded.essence_cost, gold_cost = excluded.gold_cost,
  min_rank = excluded.min_rank;

comment on column powers.name is
  'La grafía "Tornada Oscura" viene textual del PDF §6. Puede ser un typo de '
  '"Tormenta"/"Tornado" — confirmar antes de mandar a arte.';

-- ─────────────────────────────────────────────────────────────
-- Mazmorras
--
-- Una de historia por acto (PDF §5) + una de cada tipo restante.
-- Estructura fija: 3 pisos + 1 jefe, 10 de energía (PDF §6).
-- Nombres y recompensas: [TUNE].
-- ─────────────────────────────────────────────────────────────

insert into dungeons (id, name, type, min_rank, base_exp, base_gold, base_essence, story_act, sort_order) values
  ('story_01_llamado',     'El Llamado del Abismo',    'story', 'E',    120,   200,  10, 1, 10),
  ('story_02_clanes',      'Clanes y Competencia',     'story', 'D',    400,   650,  35, 2, 20),
  ('story_03_misterios',   'Misterios en Profundidades','story','B',   1800,  2400, 120, 3, 30),
  ('story_04_ritual',      'El Ritual Oscuro',         'story', 'A',   5200,  6800, 340, 4, 40),
  ('story_05_verdad',      'Verdad Abismal',           'story', 'S',  14000, 15000, 800, 5, 50),
  ('story_06_nuevo_orden', 'Nuevo Orden',              'story', 'S',  22000, 24000,1200, 6, 60),

  ('grind_fisura_menor',   'Fisura Menor',             'grind', 'E',    150,   400,  25, null, 100),
  ('grind_pozo_ecos',      'Pozo de Ecos',             'grind', 'C',    900,  2200, 110, null, 110),
  ('grind_garganta',       'La Garganta',              'grind', 'A',   4200,  9000, 480, null, 120),

  ('awaken_umbral',        'Umbral del Despertar',     'awakening', 'D',  0,     0, 300, null, 200),
  ('clan_ciudadela',       'Asalto a la Ciudadela',    'clan',      'C',  0,  5000, 200, null, 300)

on conflict (id) do update set
  name = excluded.name, min_rank = excluded.min_rank,
  base_exp = excluded.base_exp, base_gold = excluded.base_gold,
  base_essence = excluded.base_essence;

-- ─────────────────────────────────────────────────────────────
-- Monetización — precios del PDF §8
-- ─────────────────────────────────────────────────────────────

insert into gem_products (sku, gems, price_cents, currency, bonus_pct, sort_order) values
  ('gems_100',  100,   99, 'USD',  0, 10),
  ('gems_500',  500,  499, 'USD',  1, 20),
  ('gems_1200', 1200, 999, 'USD', 20, 30)
on conflict (sku) do update set
  gems = excluded.gems, price_cents = excluded.price_cents,
  bonus_pct = excluded.bonus_pct;

comment on table gem_products is
  'Precios en USD del PDF §8. MercadoPago Paraguay cobra en PYG sin decimales: '
  'al integrarlo hay que agregar filas en PYG o una tabla de conversión.';

insert into gem_sinks (id, label, gem_cost, is_cosmetic) values
  ('energy_refill', 'Recarga de energía', 10,   false),
  ('revive',        'Revivir en batalla', 50,   false),
  ('skin_basic',    'Skin cosmética',     500,  true),
  ('battle_pass',   'Battle Pass mensual',1000, true)
on conflict (id) do update set
  gem_cost = excluded.gem_cost, label = excluded.label;
