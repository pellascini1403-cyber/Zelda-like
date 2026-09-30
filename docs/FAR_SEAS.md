# The far seas: Mist Sea (west) and Current Sea (east), phase 4.5

The goal of this phase: "from the coast there must be something that draws
the eye to both horizons". This is not more of the same south sea. Each far
sea has one rule of its own and a handful of places that use it.

- **Authoring:** `tools/content/far_seas.py` (terrain, places, creatures, items, sites, discoveries, rumours) and `tools/content/q_far_seas.py` (2 quests). Build with `python3 tools/gen_content.py`.
- **Builders:** `SeaBuilder.bell_shrine`, `sea_cave`, `standing_wreck`, `split_wreck`.
- **Features:** `MistBank`, `FogBell`, `MirageShip`, `Spout`, `Whirlpool`, plus tidal and glowing `SeaCurrent`.
- **AI:** `stalker`, `current_rider`.
- **Terrain shapes:** `stack` (sea pillar) and `mesa` (flat top on cliffs).

## Geography (what was empty, what was reused)

The Phase 4 audit showed two empty seas. Both were flat floors at −22 m.

- **West (x −1430…−770):** in front of a coastal bluff about 18 m high, with nothing for 700 m. Tide Isle sat at its southern edge.
- **East (x 900…1450, z 600…1150):** below the desert's south cliffs (25–43 m), which make good launch points. Its water joins the south sea.

Content goes where the terrain gives a reason:

| Place | Terrain reason |
|---|---|
| The Teeth | the bank's middle distance, visible from the bluff |
| Echo Cave | the bluff itself |
| The Lance | against the tallest stack's wall |
| The Great Rip | along the cliff foot |
| Isla del Paso and the offshore ledge | shallows in the Rip's path |
| Wind Rock and High Isle | a glide line pointed downwind |

## West: the Mist Sea (navigation by ear, light and silhouette)

The **MistBank** has edges, clear pockets and its own clock:

- it is thick from dusk to mid-morning and thins on clear afternoons;
- fog weather makes it thickest, and storm winds tear it thin.

From outside it looks like a pale wall on the horizon, made of soft quads fading with distance. Inside, the view closes to a few tens of metres. The mist hugs the water: from a glide or a stack you look over it. The environment gets pearl-grey fog without aerial perspective, so it does not blend into the sky.

| Place / thing | What you do | Conditions |
|---|---|---|
| **The Teeth** | 5 sea stacks, silhouettes in the mist | best seen on clear afternoons |
| **Fog Bells** (4 posts) | Each has its own pitch and tolls on the swell. Ring one and the next answers (a toll and a lamp flare), so you follow the line by ear and eye to the sanctuary. Each post stands on a stone plinth: a swimmer climbs out and rests (the posts are about 100 m apart, within one swim's stamina). | lamps lit at night and in mist |
| **Sanctuary of the Bells** | a drowned belfry in the mist's clear eye; when the whole line is rung, the great bell answers and the altar lid slides aside (Mistwalker's lantern) | found by the bells, or on a clear afternoon |
| **The Lance** (wreck variant: *standing*) | A ship standing on its bow against the Wall. The only dry way in is the broken bow at the top. Dive the dark shaft, breathe at the vent halfway down, find the strongbox at the bottom, and leave by the split keel. | dive |
| **Echo Cave** (reusable *sea_cave*) | open arch → a throat whose roof dips under the sea (dive, vent) → dark chamber with glowing moss, a dry ledge, shells to gather, a cave weaver in the roof → a chimney to the secret shelf | the water system in an enclosed space |
| **The Pale Ship** | a mirage under full sail that is gone when you reach it; something floats where it stood (mist pearl, a recipe) | dawn + mist |

- **Mist dweller:**
  - Exists only in the mist and fades when it lifts.
  - Keeps pace at about 22 m and circles, following the Bellhull or a swimmer.
  - If you stop for about 3 s it closes in; move off fast and it melts back.
  - It cannot be experienced on land.

## East: the Current Sea (roads that change with the hour)

**Tidal currents** run hard on the flood and ebb and go slack at the turn (`Tide.flow`: around 6, 12, 18 and 0 h). At a given hour the same strait is either a road or a wall.

| Place / thing | What you do | Conditions |
|---|---|---|
| **The Great Rip** | a 475 m current under the cliffs; ride it end to end | the tide must be running |
| **Wind spur → Wind Rock** | a branch that carries you to a sea stack | tide |
| **The spout** | Bubbles boil (the warning), then it bursts and throws a *swimmer* out of the sea. The updraft over the rock keeps a glider rising. A Bellhull only rocks on it, so you leave the capsule to fly. | every 7 s (faster in storms) |
| **The High Isle** | a 30 m mesa: reach it by the spout and a glide, or by climbing its cliffs; the cache on top holds the riptide anklet | — |
| **Eye of the Lost** (whirlpool) | spins and draws in swimmers and boats; dive its eye to find the hoard on the bed | strongest when the tide runs |
| **The Broken Pact** (wreck variant: *split*) | The bow is aground on Isla del Paso, dry, with the log. The stern sits on an offshore ledge 11 m down, with a vent and the strongbox. The anchor chain on the bed joins them: follow it. | dive |
| **The Glowing Eddy** | the long return current glows green at night | night + running tide |

- **Rip finback** (a variant with the `current_rider` module): it slips into the nearest current upstream of you and lets it sweep it down onto you. Its body adds the drift. It differs from the finback in behaviour, not in HP.

## Rewards (no glimmer chests)

| Reward | Source | Effect |
|---|---|---|
| Mistwalker's lantern | Sanctuary altar | halves the mist you see |
| Riptide anklet | High Isle cache | ride currents harder; lose less when crossing them |
| Clearsight tea (recipe) | the Pale Ship | a buff that thins the mist |
| Materials | the far seas | mist pearls, echo shells, rip scales, abyssal pearls |
| Cosmetics | discoveries | bell-ringer's ribbon, glowing current ribbon |

- **Fish** (fishing from the shore, while swimming, or from the Bellhull's hatch):
  - the **mistfin** (mist waters, dusk to morning);
  - the **rip mackerel** (rip waters).

## Atlas (11 new wonders)

- **Mist Sea (6):** Teeth, Voices in the Mist, Sanctuary, Echo Cave, Inside the Lance, the Pale Ship (dawn + mist).
- **Current Sea (5):** the Great Rip (running tide), Eye of the Lost (dive), the Other Half (dive), the High Isle (up high), the Glowing Eddy (night + running tide).

New Atlas conditions: `mist`, `flow: strong|slack`.

## Quests (2)

- **Voices in the Mist** (Sabel): teaches navigating by the bells.
- **The Road in the Sea** (the oasis nomad): teaches the tidal currents, the spout and the glide.

Everything else stays outside the journal. Neither quest needs the Bellhull, and a test checks this.

## The Bellhull here

- Rides the currents.
- Fishes from its hatch in mist and rip waters.
- Is followed by mist dwellers.
- Carries you to the Wind Rock.
- Cannot fly: to use the spout you leave it.

Every place can also be reached without it:

- **West:** swim shore → bells → sanctuary, resting on each plinth; the Teeth can be climbed. The Echo Cave opens off the shore.
- **East:** ride the Rip and the spur to the Wind Rock (a current roughly halves the stamina a metre costs), climb the Rock, take the spout and glide. Glide from the High Isle to the whirlpool and the eddy. Isla del Paso is about 80 m from the Rip.
