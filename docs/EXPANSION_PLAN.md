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

## Phase 2 — Ecosystems `[x]`

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

## Phase 3 — Weak regions (in order) `[~]` (forest + lake done, see docs/FOREST_AND_LAKE.md; coast + sea done, see docs/COAST_AND_SEA.md)

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
* Phase 2 — ecosystems done (see docs/ECOSYSTEMS.md): 9 new families
  (15 total), 6 data-driven variants, 5 wildlife species, 13 ambient fauna
  groups, 7 regional materials + raw fish, regional chest flavours for 6
  regions, web/cold/water statuses. Every region now has its own mix
  (lake and sea have swimmers, cliffs have climbers). Fixed on the way:
  projectiles from a freed shooter, square fire particles.
  Metrics: enemy entities 6 -> 21 (15 families), animals 3 -> 8,
  items 75 -> 83, loot tables 34 -> 59. Tests: unit 497 / smoke 36 /
  systems 124 green. Captures: docs/captures/ecosystems/.
* Phase 3a/3b — Threshold Wood and Mirror Lake done (docs/FOREST_AND_LAKE.md).
  Forest rules: glowcaps (night paths + spore stealth), bellcaps (rain
  bounce), brambles (burn when dry); Canopy Walk, Hollow Tree (3 weather
  routes, slick bark, root pit), Moon Shrine (night offering gate), Weeping
  Grove, Varra's Blind. Lake: fishing (7 species over lake/sea tables),
  diving (breath, vents, underwater fog), Sunken Shrine (3 bells), storm
  buoys (lightning, electrified water, stormglass). 12 Atlas discoveries,
  Ilo's "First Cast" quest, NPC rumours. Tests: unit 512 / systems 164.

### Mini-audit after forest + lake

* New experiences that do not exist in the valley: night stealth through
  spore dust; weather-chosen routes into one place (burn / bounce / glide);
  a 40 m climb with enemies on the way and a glide as the payoff; fishing
  by hour and weather; diving with breath management; a storm that turns a
  lake field into a hazard and a resource.
* Systems reused: fire spread, weather wetness/storm/lightning, climbing
  stamina, gliding, noise/perception, quest objects + flags, rewards,
  POI pads, AI tiers, cooking specials, cosmetics.
* New mechanics: spores (stealth status), slick surfaces, weather-reactive
  props, diving/breath, bite-timing fishing, electrified water, bell
  sequences, NPC rumour rotation, terrain pits.
* Still repeated: valley/highland camps and shrines are unchanged; three
  mazes remain clones; most bounties are still "defeat N".
* Still absent: sea content for the Bellhull, highland verticality (Windstair,
  thermals), Veil phenomena, races, interiors beyond the Hollow Tree.
* Still empty: north/east/west coast, central valley south, open sea.
* Reusable for coast/sea: FishingSpot (`waters: "sea"` already placed),
  DiveState + AirVent (wreck and reef dives), StormBuoy fields (sea storm
  routes for the Bellhull), BellSequence/FlagGate (sunken ruins), eels.
* Reusable for highlands/Veil: bellcaps → wind vents/updraft zones, slick
  bark → ice, glowcaps → Veil motes that reveal paths, canopy decks →
  cliff ledges, the pit pad → Veil sinkholes.
* Atlas: 12 wonders (7 forest, 5 lake) — enough to prove the category;
  every other region needs 4-6.
* Liveliness: foxes at night, herons/white heron at the lake, fish rings,
  roosting swarms, weavers on decks, fireflies, gulls — noticeably more.

* Coast & sea ("Fase 4 — Costa y mar") done (docs/COAST_AND_SEA.md).
  Tides (sandbars, surf, HUD), currents (swimmers, divers and the Bellhull
  drift), 9 terrain islets/shelves, 7 sea places from 5 new builders
  (lighthouse, sea spire, reusable wreck ×3, castaways' camp, tide cave),
  storm spires on the Crystal Reef + squall buoys around the Leviathan,
  kelp beds, 4 sea fishing waters, fishing from the Bellhull, deep habitat,
  storm-only creatures, breath buff. 11 Atlas wonders, 5 quests, 2 NPCs
  (Sabel, Maren) with rumours. Fixed on the way: POI people sharing spawn
  ids with the builder's guards (a killed guard kept Sabel from ever
  appearing), creatures spawned before their chunk's collider falling out
  of the world and being recorded as defeated forever (now held on the
  height field), storm buoys double-hitting hulls and shocking the driver
  inside, the wreck cabin gate standing in front of a solid wall; UI
  cooldown slivers and tiny brush bars no longer build degenerate
  polygons. Open (pre-existing, also on the phase 3 commit): an
  intermittent "triangulation failed" canvas warning (2D, no visible
  effect) — not yet isolated.
  Also fixed a pre-existing test crash: the systems test called into a
  quest encounter the spawner had freed during an `await` (engine
  SIGSEGV in ~10 % of runs, also on the phase 3 commit).
  Tests: unit 548 / smoke 36 / systems 233 green. Captures:
  docs/captures/coast_sea/ (13).

### Mini-audit after coast + sea

Counts (new in this phase): places 7 POIs + 9 islets/shelves (6 with an
identity of their own); discoveries 11 (Atlas 12 → 23); creatures 5 (4
enemies: finback, needlefin, storm ray, hull lurker; 1 animal: drift
whale); NPCs 2; fish species 4 new (7 in sea waters: silverback, stormfin,
reef glint, glass shrimp, bluewater runner, lantern squid, wreck grouper);
rewards 13 items (2 gear that change diving/swimming, 1 breath broth, 3 key
items, 3 materials, 4 fish) + 1 cosmetic + 1 buff + the Bellhull storm
lining + 3 map reveals; interactions 11 kinds (tide bars, surf, currents,
lighthouse lamp, wreck lever/gate, pages, fishing from the hatch, storm
spires, squall buoys, storm blowhole updraft, leave/re-enter the capsule
at sea); quests 5; activities outside quests: sea fishing in 4 waters,
wreck and reef diving, stormglass harvesting, tide walking, whale
watching, 11 wonders. Totals: POIs 46 → 53, items 100 → 113, entities
61 → 68, sites 15 → 59, quests 83 → 88.

Draw calls (quality 2, 1280×720, per capture): coast 163–172, open sea
121–153, wreck exterior 205, wreck cabin 333, dive at the Leviathan 362,
fauna 266, fishing from the Bellhull 263, storm reef 150, squall buoys 339,
sea combat 339 (Atlas UI over the world 458). Primitives 112k–282k. The
sea is cheaper than the forest (219–578 draw calls) because there is
little to draw: kelp is one MultiMesh per bed, spires are merged meshes.

Playable sea (sampled every 16 m): 6.8 km² of water, 6.4 km² of it deep.
Within 80 m of something with a purpose: 7 %; within 150 m: 16 %. By
area: south sea 30 %, west 5 %, inland waters 12 %, east 6 %.

1. **Does the sea have its own identity?** Yes, in the south: a clock
   (tides), roads (currents), weather that changes the map (storm reef,
   squall buoys), its own fauna and a lighthouse that lights it at night.
   The west coast has one place (Tide Isle); the east has none.
2. **Does the Bellhull have a real reason to exist?** Yes, without being
   required: fishing from the hatch on the deep grounds, riding currents
   dry, a safe base to start dives from, long routes to the castaways and
   the Leviathan, and its own storm upgrade. Everything is still reachable
   by swimming with the currents or gliding from Vigil Rock.
3. **Reasons to leave the coast?** Things seen from the shore: the
   lighthouse beam, the Gull's Promise mast, the whale's spout, Vigil
   Rock's silhouette, foam lines; plus Sabel's rumours and the chart's
   map reveals.
4. **Reasons to come back after the quests?** Yes: tides (the bar only at
   low water), storms (stormglass only on the reef in a storm), night
   (lantern squid), dusk (the whale, Maren), fishing spots that rest and
   refill, the deep-water broth loop.
5. **Experiences that do not exist on land?** Fins shadowing you before a
   strike, a creature born and dissolved with the storm, drifting on a
   current, walking a road that exists two hours a day, shocked water
   around a struck spire, a whale surfacing, fishing from a capsule,
   diving into a hull.
6. **Still kilometres of water without purpose?** Yes. 84 % of the water
   is more than 150 m from anything. The south sea is now a region; the
   west and east seas and the far south beyond the Leviathan are empty.
7. **Reusable for other regions:** Tide/TideBar (any timed path: Veil
   phases, highland thaw), SeaCurrent (wind corridors for gliding, river
   rapids), the wreck builder (any sunken or listing structure), storm
   spires (lightning rods on highland peaks), storm-only creatures (any
   weather-born enemy), surfacer (burrowers, sky whales), fishing waters
   by hour/weather, the deep habitat (caves), shared-id-safe POI people.
8. **What is still repetitive?** Chests as the payoff of most places;
   the three wrecks share one silhouette language (listing hull + mast);
   levers as the only wreck puzzle; the storm-buoy "hum → strike" loop
   appears in the lake and twice at sea; encounter quests are still
   "survive N seconds".

Still empty: west and east seas, the southern horizon past the Leviathan,
highland verticality, the Veil. Next: exploration/diving depth (sea caves,
multi-room interiors), then highlands.

