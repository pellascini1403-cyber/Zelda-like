# Forest & Lake — places with their own rules (expansion phase 3)

Authoring: `tools/content/wilds.py` (+ `q_water.py` for Ilo's rod) →
`python3 tools/gen_content.py`. Builders: `src/world/structures/site_builder.gd`.
Features: `src/world/features/`.

## Threshold Wood — "this forest has rules"

Three rules the player learns by playing, each hinted by Varra's rotating
rumours (NPC `dialogue.rumors`, one per day) instead of quest markers:

| Rule | When | What it does | Where it matters |
|---|---|---|---|
| **Glowcaps open at night** | night | light paths; brushing them dusts you in spores (`spored`: noise ×0.35, creature sight ×0.5 — stealth); open caps can be picked | the Glowcap Trail to the Moon Shrine, past a Duskwing roost |
| **Bellcaps swell in rain** | rain / wet | limp when dry; taut and springy when wet — landing on one throws you ~5 m up | the Weeping Grove bellcap ladder to the Hollow Tree's knot-hole |
| **Dry thorns burn, wet ones hold** | dry weather | bramble walls burn away for good with any fire (fire weapon, bomb, grass fire, an imp's trail); in rain they smoulder | the Hollow Tree's ground door |

### Connected places (discoverable in any order)

```
 Hunters' Lodge ──red ribbons──▶ Varra's Blind (stealth hood)
      │
 Elder Tree ──Glowcap Trail (night, spores, roost)──▶ Moon Shrine
      │                                           (3 glowcaps at night → Moon Gate:
      │                                            hush tea recipe, moonlit ribbon,
      │                                            map points at the Hollow Tree)
 Canopy Walk (climb 4 × 10 m, weavers on decks) ──glide from the nest──┐
                                                                        ▼
 Weeping Grove (rain: bellcap ladder) ──knot-hole──▶ HOLLOW TREE ◀──door (dry: burn brambles)
                                                     gallery ring → root ladder → heart pit
                                                     (cave weavers, glowmoss, Heartroot chest)
```

* **Canopy Walk** (vertical): four 45 m trunks, decks every 10 m (rest
  stops for climbing stamina), rope bridges, a crow's nest at +40 m that
  looks straight at the Hollow Tree's open crown. Crag Weavers wait on the
  decks and hunt climbers. escalada + tejedora + pasarela + planeo.
* **Hollow Tree** (underground): slick living bark (no grip: `no_climb`),
  three entrances chosen by the weather, a gallery ring inside, a pit 7.5 m
  below ground (terrain `pit` pad) with the Heartroot. lluvia + fuego +
  hongos + enemigo.
* **Moon Shrine** (memorable, not a pavilion clone): a round moon-pool in a
  ring of standing stones and a sealed *round* gate in the rock; only
  answers at night. noche + fauna + sigilo + descubrimiento.
* **Weeping Grove** (mysterious): willows with hanging strands hiding the
  bellcaps; exists as a place only when it rains.

Forest enemies (different from the valley — no thornling packs): Bramble
Carapaces, a rare **Elder Carapace** (sap burst that glues you), Spitters,
Duskwing swarms and Wisps at night, Crag Weavers on cliffs and decks, Cave
Weavers in the root pit. Wildlife: burrowhops, woolhorns, **brush foxes at
night**, fireflies/bats/sparrows, the rare **Mist Fox** (fog, dawn).

## Mirror Lake — water, fish, depth, storms

| System | How | Reused for |
|---|---|---|
| **Fishing** (`FishingSpot`, `Fishing`, `data/fishing.json`) | rings on the water → cast → wait → pull in a 1.1 s window. Species by waters/hour/weather: perch (day), pike (dawn/dusk), **moon carp** (night, rare), **stormfin** (storm). Spots rest after 3 catches. Rain makes fish bite sooner. | coast/sea: `waters: "sea"` spots already placed (silverback, rare reef glint) |
| **Diving** (`DiveState`, `AirVent`) | dodge on the surface to dive; sink, hold jump to rise; stamina = breath; out of breath = drowning damage; bubble vents refill; breath/swim gear (`tide_charm`) | sea caves, wrecks, reefs |
| **Sunken Shrine** | lake bed at −9 m. Front door buried; enter by the broken roof or the side crack. Three drowned bells (inside, terrace, rubble) open the sanctum (`BellSequence` → `FlagGate`). Air vent inside; an eel keeps the waters. | any ruin under water |
| **Storm buoys** (`StormBuoy`) | fair weather: rusty floats to hop across. Storm: one hums (telegraph), is struck: electrified water (shock ×2 on anything wet — you, eels), stormglass forms on its crown. More eels in storms. | sea storm fields |

Lake wonders: Sunken Shrine (dive), Drowned Lanterns (night, on the
water), Storm Buoys (storm), Moon Carp (fishing), White Heron (dawn, rare).
Ilo teaches fishing ("First Cast": rod → a perch → recipe + his rumours).

## Atlas of wonders

Twelve discoveries (7 forest, 5 lake): name, short text, region, how it is
found (derived from conditions: night / rain / storm / fog / dawn / up high
/ deep down / diving / with a rod), icon, reward, found/unfound. Unfound ones
show the rumour hint. Rewards fit the place: glowcaps, bellcap skin,
heartwood, mist fox fur, stealth hood, rootgrip charm, pearls, stormglass,
tide charm, cosmetics (moonlit ribbon, heron plume), a cooking recipe.
Most are not quests: you find them, the Atlas records them, you move on.

## The sea — built in the coast & sea phase

See docs/COAST_AND_SEA.md: the lake's water systems (fishing, diving,
air vents, storm buoys, gates) now run the south sea.
