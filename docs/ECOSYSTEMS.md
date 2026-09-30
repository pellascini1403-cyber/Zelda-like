# Ecosystems — enemies, variants, fauna

Authoring: `tools/content/ecology.py` → `python3 tools/gen_content.py`
(entities, visuals, loot, region spawn tables, strings in 8 languages).
Architecture: `docs/EXPANSION_PLAN.md` (phase 1).

## Rule

A new creature must change **how the player fights or moves**: a different
locomotion, a behaviour module, a status it inflicts, or a counter that uses
another system (fire, rain, storm, water, parry, stealth). A recolour with
more HP is rejected by `test_ecosystems` (variants must differ in behaviour,
locomotion, resistances or attack elements).

## Families (15)

| Family | Locomotion / modules | What it asks of you | Counter | Regions |
|---|---|---|---|---|
| Thornling (+ Rime) | ground | packs, pounces | fire; sneak at night (sleeps) | valley, forest, highlands (Rime: snow, cold bite slows) |
| Bulwark (+ Stormcaller) | ground | heavy slams | electric; Stormcaller drinks storms and discharges | highlands, valley (storm) |
| Spitter (+ Tidepool) | ground (+ ambush) | ranged acid | close the gap; Tidepool hides in pools and soaks you (water → shock ×2) | everywhere, coast |
| Wisp | flying | night pulses | — | night everywhere |
| Scuttler | ground | desert packs | ice | desert |
| Shade | ground | Veil elite | fire | Veil |
| **Gale Kite** | flying + `swoop` | circles high, dives on a telegraphed shadow | dodge/parry the dive, punish it skimming the ground; electric ×1.5 | highlands, coast, cliffs |
| **Mire Eel** | aquatic + `submerge` | untouchable while deep, surfaces to snap/jet | hit it in the surface window; it is always soaked (shock ×2) | lake, sea |
| **Crag Weaver** (+ Cave, Veil) | climber + `drop_from_above` | waits on cliffs, drops on you, hunts you while you climb; webs slow | look up; fire ×1.6; Cave: ambush in the dark, scared of fire; Veil: also phases | highland cliffs, forest cliffs, caves, Veil |
| **Bramble Carapace** (+ Shellback) | ground + `front_armor` | shell deflects frontal hits, rolls at you | circle behind, or stagger (slam, bomb, parry) to flip it: ×1.8 damage | forest, coast (Shellback) |
| **Cinder Imp** | ground + `ignite` | sets dry grass on fire as it runs | rain or water douses it (×1.6 damage, no fire) | valley (dry weather), desert |
| **Dune Burrower** | burrower + `burrow` | hunts by vibration under the sand, erupts | stand still to lose it; hit it while exposed | desert |
| **Hush Drifter** | flying + `phase` | fades out of reach and back | fire/heat forces it visible and burns it | Veil |
| **Glint Thief** | ground + `steal` | steals glimmer on a hit and runs | chase it — it tires after 6 s; catch = glimmer back with interest | roads (valley, lake, coast) |
| **Duskwing** | flying + `swarm` + `fire_shy` | night swarms wheel and strike one at a time | fire scatters them (×2 damage) | night: valley, forest, highlands |

## Behaviour modules (`src/ai/behaviors/`)

`ambush`, `swoop`, `front_armor`, `submerge`, `burrow`, `drop_from_above`,
`phase`, `steal`, `ignite`, `fire_shy`, `swarm`, `storm_charged`. Listed in
`ai.behaviors`; tuning keys next to them in `ai` (see each class header).
Module-owned attacks use `"type": "module"` (never picked by chase).

## Wildlife (Tier 0, real animals)

Woolhorn, Burrowhop, Gilded Hop (rare), Windstrider (mount) + **Crag Goat**
(climbs cliffs), **Reed Heron** (lake shallows, very skittish), **Tide Crab**
(coast), **Dune Fox** (desert, night only), **Lumen Stag** (Veil, rare,
drops a lumen antler).

## Ambient fauna (Tier 1-3, `data/fauna.json`)

Gulls, sparrows, ravens, snow finches, bats, lake minnows, silverbacks, rare
reefglints, fireflies, petalwings, Veil motes, sand skitters, tide crabs.
MultiMesh groups by region/period/weather; scatter from the player, from
noise and (bats) from fire. Budget per quality preset: `ambient_groups`
(2/4/6/8) within `ambient_distance` (70-130 m).

## Status effects added

`webbed` (web: −50 % speed), `chilled` (cold/ice: −20 % player speed,
−35 % creature speed), `wet` from water attacks (then electric ×2).
