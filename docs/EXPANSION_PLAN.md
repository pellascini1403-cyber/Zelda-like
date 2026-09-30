# VELA — Content & Variety Expansion Plan

Status-tracked plan for the "Expansión profunda de contenido y variedad"
phase. Source of truth for what exists: the content audit (baseline numbers
below). Rule of the phase: **more distinct experiences, not bigger counters**.
Every addition must change how the player moves, fights, explores or reads a
place; if something exists five times, the sixth must add a new verb.

Status legend: `[ ]` planned · `[~]` in progress · `[x]` done.

## Baseline (audit, before this phase)

| Area | Count | Main problem |
|---|---|---|
| Enemy families | 6 (Thornling, Bulwark, Spitter, Wisp, Scuttler, Shade) | all ground or hover; nothing aquatic, climbing, swooping, burrowing |
| Bosses / mini-bosses | 3 + 5 | no aquatic, vertical or weather boss |
| Animals | 3 + mount | no birds, fish, night or Veil fauna |
| Quests | 82 (177 stages) | lake, coast, sea, highlands and Veil thin |
| POIs | 42 | north/east/west coast, central valley, sea: empty |
| Discoveries (non-quest) | 0 | no category |
| Regions with own enemy mix | 2 of 7 (desert, veil) | forest/lake/coast reuse valley enemies |
| Sea (≈7 km² of water) | 0 activities | the Bellhull has nothing to do |

## Reuse vs. extension (Phase 1 dependency map)

| System | File(s) | Decision |
|---|---|---|
| EntityType + DB.reload | `src/data/entity_type.gd`, `src/autoload/database.gd` | **extend**: `variant_of` deep merge before `from_dict`; new fields `locomotion`, `behaviors`, `habitat` |
| Visual profiles | `data/visuals.json`, `ArtStyle` | **extend**: variants inherit the base profile + override; unique colour per species stays enforced |
| Creature body | `src/ai/creature.gd` `_move/_avoid` | **extend**: locomotion branches (aquatic, climber, burrower, flyer altitude offset) |
| AIBrain | `src/ai/ai_brain.gd` | **extend**: behaviour modules (`AIBehavior`) registered from data; they can pre-empt a state, add states, filter damage |
| Attack types | `AttackData`, `AttackState` | **reuse** (melee/lunge/projectile/slam/pulse/charge/volley/eruption/summon); add `swoop` + `burst` only |
| Spawn tables | `RegionData`, `SpawnDirector` | **extend**: `habitat` (land/water/cliff), `weather`, `hours`, `rank`; water and cliff slots stop being discarded |
| Fauna | `Animal`, `AnimalBrain` | **reuse** for Tier-0 animals; **new** `AmbientLife` (MultiMesh flocks/schools, Tier 1-3) |
| Discoveries | `QuestSpawner`, `QuestObject`, `Rewards`, `WorldState` | **extend**: QuestSpawner gets a discovery source; new `DiscoveryDirector` detects/records `disc:<id>`; Journal gets an Atlas tab |
| World events | `WorldEventDirector` | **reuse**, add multi-system event kinds later (Phase 3/10) |
| Rewards | `src/quests/rewards.gd` | **extend**: `discovery`, `vehicle_part`, `service` unlock flags go through existing `flags` |
| Loot | `loot.json`, `Chest` | **extend**: regional flavour tables (`<table>@<region>`) resolved at open time |
| Save | WorldState flags / defeated | **reuse**: every new state is a flag (`disc:`, `svc:`, `rw:`), no save-version bump |
| Localization | `tools/content/*.py` → `gen_content.py` | **reuse**: all new text through `L(...)` in 8 languages |
| Quality / AI tiers | `QualityManager`, `AIManager` | **reuse**; AmbientLife reads the same presets |

Nothing is rewritten. Builders are only added where a silhouette cannot be
expressed with the existing ones (bat/kite wings, beetle shell, jelly bell,
fish, bird).

## Phase 1 — Content architecture `[x]`

1. Entity **variants**: `"variant_of": "<base id>"` in entities.json, deep
   merged (dicts merged, arrays replaced) — Spider → Venom / Cave / Veil /
   Queen without duplicated definitions. Visual profiles inherit likewise.
2. **Locomotion**: `ground | flying | aquatic | climber | burrower`
   (`flying: true` stays valid). Aquatic creatures never leave water;
   climbers walk steep faces and drop from above; burrowers travel
   hidden and surface to attack; flyers get a controllable altitude offset.
3. **Behaviour modules** (`ai.behaviors: [...]`, params in `ai`):
   `ambush`, `swoop`, `guard`, `front_armor`, `submerge`, `burrow`,
   `drop_from_above`, `phase`, `steal`, `ignite`, `storm_charged`,
   `fire_shy`, `swarm`. Each is one small class; any enemy can combine them.
4. **Spawn tables**: `habitat`, `weather`, `hours`, `rank` per entry;
   SpawnDirector routes water slots (sea + lake) to aquatic entries and steep
   slots to climbers.
5. **AmbientLife** (`data/fauna.json`): flocks of birds/gulls/bats,
   butterflies, fireflies, fish schools, Veil motes. Tier 1 = MultiMesh boids
   near the player, Tier 2 = seeded state only, Tier 3 = nothing. Fish scatter
   from the player and from boats; birds lift off on noise.
6. **Discoveries** (`data/discoveries.json`): condition set (period, hours,
   weather, ability, vehicle, diving, min height), trigger (reach, interact,
   see), spawns (reuses quest spawn kinds), reward, Atlas entry.
7. **Regional loot** tables and the new reward kinds.
8. Tests: variant merge, locomotion constraints, behaviour registration,
   spawn routing, discovery conditions and one-time rewards, fauna tiers.

## Phase 2 — Ecosystems `[ ]`

New families (ids provisional) — each changes how you fight or move:

| Family | Locomotion / module | Counterplay | Home |
|---|---|---|---|
| Gale Kite | flying + swoop | its ground shadow telegraphs the dive; parry/dodge, wind knocks it down | highlands, coast |
| Mire Eel | aquatic + submerge | surfaces to lunge; electric in water; boats | lake, sea |
| Crag Weaver (spider) + Cave / Veil / Queen | climber + drop_from_above | attacks you while you climb; webs slow | highlands, caves, Veil |
| Bramble Carapace (beetle) + Shellback | ground + front_armor | hit from behind/flip with slam; rolls | forest, coast |
| Cinder Imp | ground + ignite | sets grass alight; rain/water kills its flame | valley, desert edge |
| Dune Burrower | burrower | dust trail telegraph; stop moving to lose it | desert |
| Hush Drifter | floating + phase | only hittable when visible; silences stamina regen | Veil |
| Glint Thief | ground + steal | steals glimmer and flees → chase | roads, camps |
| Duskwing (bats) | flying + swarm + fire_shy | night swarms; torches/fire scatter them | caves, forest night |

Variants: Rime Thornling (cold, highlands), Stormcaller Bulwark (storm),
Tidepool Spitter (coast). Fauna: Crag Goat (climbs), Reed Heron, Tide Crab,
Dune Fox (night), Lumen Stag (Veil) + AmbientLife groups.

## Phase 3 — Weak regions (in order) `[ ]`

Forest → Lake → Coast/Sea → Diving → Highlands → Veil. Each gets its own
enemy/fauna mix, 2-4 unique places with a mechanic, weather/night content,
and the regional loot flavour. Fishing (lake), reduced diving (oxygen,
underwater fog, treasures) and sea content for the Bellhull are built here.

## Phase 4 — Exploration `[ ]`
~30 discoveries (buried door, night tree, waterfall cave, fog bell, storm
isle, glide-only ruin, gravity rift...), caves, islets, aerial routes.

## Phase 5 — Quests `[ ]`
~20-30 multi-verb quests built on Phase 2-4 experiences (target 105-115).

## Phase 6 — NPCs `[ ]`
Deepen 8-10 NPCs: services (smith repair/upgrade chain, fisher, hunter,
climber, nomad, pilgrim vendor, cartographer maps), routines, weather shelter.

## Phase 7 — Equipment `[ ]`
Region/activity sets (Climber, Wind, Desert, Snow, Veil, Tide), bow depth,
elemental blades, smith upgrades. Stats never tied to cosmetics.

## Phase 8 — Bosses `[ ]`
Weaver Queen (vertical), Tide Serpent (aquatic/Bellhull), Stormcaller
(weather), Glint King (chase).

## Phase 9 — Optional activities `[ ]`
Fishing, vehicle and Windstrider races, climb/glide challenges, creature
search.

## Phase 10 — Balance & polish `[ ]`
Reward frequency, density, repetition audit, performance tour on low tier.

## Performance, save, localization (all phases)

* AI: new creatures use the existing FULL/REDUCED/DORMANT tiers; behaviour
  modules tick only on FULL. AmbientLife is one MultiMesh per group, no
  physics bodies, capped by quality preset.
* Save: new state = WorldState flags (`disc:`, `svc:`), no new sections
  unless unavoidable; rewards always via `Rewards.grant` (no double pay).
* Localization: all strings through the content DSL (8 languages); the
  unit test fails on any missing key.

## Progress log

* Phase 1 — architecture done: variants, locomotion (aquatic/climber/burrower/flyer lift), 12 behaviour modules, habitat spawn routing, AmbientLife (13 fauna groups, tiered), discoveries + Atlas, regional loot hook, zone spawn kind. Tests: unit 375 / smoke 36 / systems 102 green.
