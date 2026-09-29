# Quests — content-first layer

Priority: fun → exploration → variety → combat → discovery → quests → progression → story.
The story fits in one breath: *the Stillwake, a silence born in the Veil, is smothering the wind;
Oren, the last Wind Warden, vanished trying to stop it; his apprentice relights the Warden beacons
of each land and faces the Stillwake Warden.* Dialogue is one or two lines; places, events and
objects tell the rest.

## 1. Quest System

- `src/autoload/quests.gd` — lifecycle LOCKED → AVAILABLE → ACTIVE → COMPLETED (or COOLDOWN for
  repeatables). Quests are lists of **stages**; a stage completes when its required objectives are
  done. Objectives listen to EventBus facts; nothing else in the game knows about quests.
- Starts: `auto`, `talk:<NPC>`, `event` (the discovering fact itself starts and counts, incl. walking
  into a place), `interact:<object>`, `poi:<id>`, `flag:<flag>`, `board` (bounties).
- Failure (escort/protect/survive) resets only the current stage; the journal can restart any stage
  with live content. No permanent dead ends.
- World side: `src/quests/` — `QuestSpawner` streams content near the player (objects, nests,
  creatures, captives, encounters, ring courses, puzzles, chests, smoke/light cues); `QuestObject`,
  `QuestNest` (fire/explosion weak), `QuestActor`, `QuestEncounter`, `RingCourse`, `Rewards`,
  `QuestValidator`. Beacons, bounty boards and Warden altars live in `src/interaction/`.
- UI: journal (story / tales / discoveries / bounties, rumours with who and where, bonus
  objectives, region · difficulty · length, restart step), tracker, compass/map markers (exact,
  area circle, or none), encounter banner, reward popup, board and altar panels.

## 2. Quest Data Format

`data/quests/NN_*.json`, generated from `tools/content/*.py` by `python3 tools/gen_content.py`.

```
{id, type: main|side|discovery|bounty|challenge, category, region, difficulty 1-5,
 duration: short|medium|long, title_key, desc_key, start, requires[], requires_flags[],
 requires_abilities[], start_when{period,weather,region}, offer_lines[], repeatable,
 cooldown_hours, board, spawns[] (when: open|available|active|always),
 stages[{objectives[], spawns[], talk_lines[], hint_lines[], rewards{}, on_complete_flag}],
 rewards{}, bonus_rewards{}, unlocks{flags[]}}
objective: {type, target ("group:<g>" allowed), count, item, text_key | text_key+text_args,
            optional, conditions{period,weather,state,min_y,region}, marker, pos, radius,
            min_y, metric: distance|height, par, hint: marked|area|none, area_radius}
```
Objective types: reach, kill, clear, boss, collect, gather, deliver, retrieve, interact, destroy,
discover, region, talk, flag, puzzle, ability, ability_use, craft, cook, mount, open_chest, climb,
glide, swim, escort, protect, survive, course, sneak, event — plus aliases (reach_location,
defeat_enemy, hunt, defeat_boss, collect_item, gather_material, investigate, activate, rescue,
use_ability, solve_puzzle).

## 3. Main Quest Structure

16 quests in three acts, each leaning on a different activity (report: `docs/QUEST_VARIETY.md`):
Act I valley — glide tutorial, protect + fire-weak nest, fire puzzle, boss. Act II — altar/jade
intro, then lake (braziers + swim), coast (nests + glide), heights (climb + mini-boss) in any order;
desert road, caravan escort + survive, vault puzzle + delivery, Matriarch. Act III — Veil survival,
three anchors, floating-isle traversal, the Warden. Lit beacons raise light pillars visible
island-wide.

## 4. Side Quest Structure

30 side, 19 discovery, 8 bounties, 6 challenges across all regions: combat (camps, nests,
mini-bosses), exploration (clue trails, bells, obelisks only in sandstorms, stones only at night),
puzzles (fire, wind vanes via Gust Step or thermals, pressure plates), gathering/cooking/crafting,
NPC tales (strays, courier rounds, captives, lost scholar escort), challenges (glide, run, swim and
mounted ring courses with par times, a combat trial). Repeatable bounties rotate daily on boards and
avoid recently done categories.

## 5. Discovery Content

Mix of marked, area-only, unmarked and secret content: smoke columns over trouble, light pillars
over relics, a gilded rare creature at dawn/dusk, flowers that bloom only at night, obelisks only in
sandstorms. Emergent events (`data/world_events.json`): travellers under attack (live encounter
with a shout for help), desert raids, unalerted elite patrols, rare creatures, wisp lights, storm
glass — at most one per kind, recently seen ones skipped.

## 6. Reward System

`Rewards.grant(r, source)` — items, glimmer, jade, ability, flags, max stamina/health, recipes,
cosmetics (effects only: blade trail, glider ribbons, dash echo — the player model is never
recoloured), map reveal. Every source is recorded before paying: nothing pays twice. Jade buys
blessings at Warden altars (`data/upgrades.json`). Every quest must pay something (validated).

## 7. Content Generation Guidelines

Write quests in `tools/content/q_*.py` with `quest/stage/obj`, text as `L(en, es, pt, fr, de, ja,
ko, zh)` or shared templates `T("QO_T_DEFEAT", "NAME_X")`. Place things with `pos` (or relative to
a `poi`), check ground with `godot --headless -- --probe x,z` / `--probe-map`. Run
`tools/gen_content.py`, then the unit tests: `QuestValidator` rejects unknown targets, objects not
present on their step, clear groups smaller than their count, givers who live nowhere, flags nothing
sets, prerequisite cycles and quests without rewards; the localization test checks every key and
template in 8 languages.

## 8. Anti-Repetition Guidelines

`python3 tools/quest_variety.py [--md]` fails on near-duplicate step sequences in the same region
or from the same giver, too many kill-and-report quests (>15%), repeated main-line activity, or any
core mechanic unused; it reports category spread per region, session lengths and reward kinds.
Rules of thumb: alternate activities, vary rewards, prefer a new activity over a new scene of lore.
