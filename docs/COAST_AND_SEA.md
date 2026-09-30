# Coast & Sea — "the sea is another part of the world" (expansion phase 4)

Authoring: `tools/content/seas.py` (places, islets, creatures, fish, sites,
discoveries, rumours) + `tools/content/q_sea.py` (5 quests) →
`python3 tools/gen_content.py`. Builders: `src/world/structures/sea_builder.gd`.
Features: `src/world/features/` (tide, tide_bar, surf, sea_current, kelp,
lighthouse_lamp, storm_buoy spire variant). Everything below reuses the
lake's water systems (docs/FOREST_AND_LAKE.md): FishingSpot, DiveState +
AirVent, StormBuoy, FlagGate, QuestObject pages.

## Map: land → coast → water → sea

```
 Dawn shore (Sabel, the tidekeeper; beach, tide crabs, needlefin shallows)
   │  Gull Current (foam line, swim or sail: it carries you)
   ▼
 Tidewarden Light (islet + lighthouse: relight at NIGHT → chart, map reveals)
   │  Light Current
   ▼
 Vigil Rock (44 m sea spire: climb, gale kites, updraft) ──glide──▶ Gull's Promise
   │  Home Current back to shore                          (wreck on a shoal)
   ▼
 ── the Bellhull's sea (reachable swimming with the currents, faster by boat) ──
 Castaways' Islet (story in objects; Maren rows back at dusk)
 Crystal Reef (fair: wadeable garden, reef fish │ storm: 7 lightning spires, rays)
 Iron Leviathan (deep wreck on a silt bed, 8 squall buoys around it, kelp)
 Vanishing Bar (exists only at LOW tide: buried chest)
 Deep-water fishing grounds (bluewater runner by day, lantern squid at night)
 West coast: Tide Isle (causeway at low tide, surf at high tide, storm
 blowhole to a high ledge, drowned side tunnel) + kelp lagoon + sunk skiff
```

## The coast's rules (learned by playing; Sabel's rumours hint them)

| Rule | When | Effect | Where |
|---|---|---|---|
| **Tides** (`Tide`) | low ≈ 22–2 h and 10–14 h, high ≈ 6 h and 18 h | sandbars (`TideBar`) rise dry at low water, drown at high; surf (`Surf`) throws you out of cave mouths at high water; the HUD shows the tide on the coast | Tide Isle causeway, Vanishing Bar, tide cave mouth |
| **Currents** (`SeaCurrent`) | always | a foam strip that pushes swimmers, divers **and the Bellhull** (+1.2×); ride it out, fight it back | Gull / Light / Home currents; the reef rip pulls you out to sea |
| **Storms change the sea** | storm | reef spires hum then take lightning (electrified water, stormglass on the crown); squall buoys around the Leviathan; storm rays rise; the Tide Isle blowhole becomes an updraft to the storm ledge | Crystal Reef, Leviathan, Tide Isle |
| **Night** | night | the lighthouse lamp only takes a flame after dark; lantern squid rise | Tidewarden Light, deep grounds |
| **Dusk** | 16–21 h | Maren is on her islet; the drift whale surfaces west of Vigil Rock | Castaways' Islet, open sea |

Storms change decisions, not just damage: in fair weather the reef is a safe
fishing and wading shelf; in a storm it is the only place that grows
stormglass and glass shrimp bite more, but the spires shock anything wet
and storm rays hunt. The Leviathan's squall buoys shock hulls: the safe
route goes around, the rich one goes through (or line the hull with
stormglass: the "Storm Night" reward `bellhull_stormproof`).

## Places (7 POIs + 9 terrain islets, data-driven)

| Place | Type | Identity | Ways in |
|---|---|---|---|
| Tidewarden Light | `lighthouse` | spiral stair, lamp room lever (night), keeper's chest, dock | swim the Gull Current, sail, glide from the cliffs |
| Vigil Rock | `sea_spire` | crooked 44 m pillar with ledges, nest cache, gale kites | climb; updraft on the lee face; the glide launch point |
| The Gull's Promise | `wreck` | listing hull on a shoal, jammed cabin (lever in the hold), log, keel bell, hull lurker | **deck hatch** (glide/boat/climb), **hull breach** (dive), **stern windows** (swim), **stove-in cabin roof** (drop from a glide) |
| The Iron Leviathan | `wreck` | 34 m iron hull at −15 m on a silt bed, air vent in the hold, 2 lurkers, kelp | dive (vents, deepwater broth/mask); its mast is a storm spire |
| Smugglers' Skiff | `wreck` | small sunk boat in the Tide Isle kelp lagoon | dive (no vent: a short one) |
| Castaways' Islet | `castaway_camp` | three collapsed shelters, upturned boat roof, cold signal pit, grave; 3 pages; Maren at dusk | swim (long), sail |
| Tide Isle | `tide_cave` | rock ring with a surf mouth, pool chest, storm-only high ledge, drowned side tunnel with a vent | causeway at low tide, swim the tunnel, blowhole updraft in storms |

The wreck builder is one reusable architecture (`SeaBuilder.wreck`):
length, beam, pitch/yaw/roll, sunk depth, breach index, mast height,
optional jammed cabin (`cabin_gate` flag + lever opens its doorway; the
stern roof is stove in), vent, pages, guardians.
Three wrecks from one builder look and play differently.

## The Bellhull at sea (premium, never required)

* Floats (water mode), carried or slowed by currents.
* **Fishing from the hatch**: idle over a spot and interact — you cast
  without climbing out (deep grounds are its natural use).
* **Starting dives**: climb out at sea (you land in the water), dodge to
  dive, climb back in afterwards.
* Takes lightning through the hull in storm fields unless lined with
  stormglass (Storm Night).
* Long routes (castaways, deep grounds, Leviathan) are faster, drier and
  safer by boat; every one of them can also be reached by swimming with
  the currents and resting on islets, or gliding from Vigil Rock.
* Validated: no main or sea quest has a vehicle condition (systems test).

## Fauna and enemies (unique placeholder colours, ≥48 RGB apart)

| Creature | Role | Behaviour | Only at sea? |
|---|---|---|---|
| **Finback** (`#0c70b9`) | surface predator | `submerge`: its fin cuts the surface while it shadows you (`fin_depth`), then it surfaces to strike; electric ×1.4 | yes — never leaves the water |
| **Needlefin** (`#82c3bf`) | marine swarm | `swarm` school that rings you and darts one at a time; electric ×2 | yes |
| **Storm Ray** (`#4723a5`) | storm creature | flies low over waves, `swoop` + `storm_charged`, arcs lightning; `storm_only`: fades into the spray when the sky clears | yes (open sea / reef, storms) |
| **Hull Lurker** (`#a42b4a`) | wreck guardian | amphibious crab on the sea bed, `ambush` + `front_armor` (flip it) | in wrecks |
| **Drift Whale** (`#7e446e`) | gentle giant | `surfacer`: rises every ~14 s to breathe (spray seen from afar), never attacks | yes |

Habitats: `coast` land, `water` (shallows), `deep` (sea bed below −14 m),
`cliff`. Storm rays and deep finbacks only spawn in `deep`.

## Sea fishing (reuses `Fishing`)

| Waters | Species |
|---|---|
| `sea` (shore) | silverback, stormfin (storm), raw fish |
| `reef` | reef glint (10–15 h, clear), glass shrimp (more in storms), silverback |
| `deep` | bluewater runner (day), lantern squid (night), stormfin (storm) |
| `wreck` | wreck grouper, silverback, stormfin (storm) |

7 spots; each rests after 3 catches, so there is no money loop. Lantern
squid + bluewater runner + frostmint = **deepwater broth** (breath buff:
−30 % breath drain for 4 min).

## Atlas: 11 sea wonders

Tidewarden Light (night), Vigil Rock's crown (up high), the Gull's Promise,
the Iron Leviathan (diving), the Crystal Reef, the Reef in a storm, the
Castaways (pages, Maren at dusk), the Vanishing Bar (low tide), the Tide
Cave, the Drift Whale (dusk), the Lantern Squid (with a rod). Conditions
show in the Atlas ("at low tide", "at night", "diving"...).

## Quests (5) — few, and each ties systems together

| Quest | Teaches |
|---|---|
| First Crossing (Sabel) | currents + the lighthouse at night |
| The Ship That Never Returned | a wreck's entrances, the hold lever, the log |
| Under the Keel | cooking a breath broth → deep dive → vents → strongbox |
| Storm Night | the reef in a storm, a survive encounter, stormglass (hull lining) |
| The Vanishing Isle (Maren) | tides as a key: the objective only completes at low tide |

Most of the sea stays outside the journal: the whale, the storm reef, the
squid, the skiff, the tide cave, the deep grounds.

## Rewards that change how you explore

Deepwater mask (head, −40 % breath drain), driftwood charm (+30 % swim
speed, −15 % breath drain), deepwater broth recipe, tidewarden chart +
three map reveals, Bellhull storm lining, tide ribbon (glider trail),
abyssal pearls, stormglass.

## Discovery cues (no markers)

The lighthouse beam at night; the mast of the Gull's Promise over the shoal;
the whale's spout; the foam lines of the currents; gulls; the hum of the
spires before a strike; surf at the cave mouth; Sabel's five rumours.

## Performance

Kelp is one MultiMesh per bed; spires use merged meshes and a shared
static glass material; every sea prop has a visibility range; the sea
structures build through the same POI queue (one per frame) and free at
800 m; currents are one particle system each with a bounded AABB; the
lighthouse light fades out beyond 250 m. Draw-call numbers per capture are
in docs/EXPANSION_PLAN.md (phase 4 mini-audit).

## Known limits (honest)

* The water surface does not rise and fall with the tide: sandbars and
  surf carry the tide instead.
* Wind does not push the Bellhull yet (currents do).
* Wreck interiors are open hulls, not multi-room interiors.
