#!/usr/bin/env python3
"""Quest variety report (anti-repetition, docs/QUESTS.md §8).

Reads data/quests/*.json and reports:
  * near-duplicates: same objective sequence in the same region or from
    the same quest giver (hard failure)
  * main-line alternation: consecutive main quests leaning on the same
    primary activity
  * kill-and-report share, category spread per region, session lengths
  * which mechanics the content actually asks the player to use
  * reward variety
Exit code 1 when a hard rule fails.   Run: python3 tools/quest_variety.py [--md]
"""
import glob
import json
import os
import sys
from collections import Counter, defaultdict

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ALIASES = {"reach_location": "reach", "defeat_enemy": "kill", "hunt": "kill", "defeat_boss": "boss",
           "collect_item": "collect", "gather_material": "gather", "investigate": "interact",
           "activate": "interact", "rescue": "interact", "use_ability": "ability_use",
           "solve_puzzle": "puzzle", "defeat_group": "clear"}
FILLER = {"talk"}


def canon(o):
    return ALIASES.get(o.get("type", ""), o.get("type", ""))


def load():
    quests = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "quests", "*.json"))):
        with open(path, encoding="utf-8") as f:
            quests.extend(json.load(f))
    return quests


def course_modes(q):
    modes = {}
    for sp in q.get("spawns", []) + [sp for st in q["stages"] for sp in st.get("spawns", [])]:
        if sp.get("kind") == "course":
            modes[sp.get("id")] = sp.get("mode", "run")
    return modes


def signature(q):
    modes = course_modes(q)
    out = []
    for st in q["stages"]:
        steps = []
        for o in st["objectives"]:
            c = canon(o)
            if c == "course":
                c += ":" + modes.get(o.get("target"), "?")
            if c == "boss":
                c += ":" + o.get("target", "")   # every boss fight is its own
            steps.append(c)
        out.append(tuple(sorted(steps)))
    return tuple(out)


# What a quest is "about": its most defining step.
RANK = ["boss", "escort", "protect", "survive", "puzzle", "destroy", "sneak", "clear", "kill", "course",
        "climb", "glide", "swim", "mount", "craft", "cook", "gather", "collect", "retrieve", "interact",
        "open_chest", "deliver", "reach", "discover", "region", "ability_use", "ability", "flag", "event", "talk"]


def primary(q):
    best = len(RANK)
    for st in q["stages"]:
        for o in st["objectives"]:
            c = canon(o)
            if not o.get("optional") and c in RANK:
                best = min(best, RANK.index(c))
    return RANK[best] if best < len(RANK) else "talk"


with open(os.path.join(ROOT, "data", "world.json"), encoding="utf-8") as _f:
    POI_PUZZLES = {p["id"]: p["puzzle"].get("type", "") for p in json.load(_f)["pois"] if "puzzle" in p}


def mechanics(q):
    """Player verbs a quest asks for (spawn kinds and place puzzles count too)."""
    out = set()
    for st in q["stages"]:
        for o in st["objectives"]:
            if canon(o) == "puzzle" and o.get("target") in POI_PUZZLES:
                out.add({"plates": "physics", "braziers": "fire"}.get(POI_PUZZLES[o["target"]], "puzzle"))
    for st in q["stages"]:
        for o in st["objectives"]:
            c = canon(o)
            out.add({"kill": "combat", "clear": "combat", "boss": "boss", "sneak": "stealth", "protect": "protect",
                     "escort": "escort", "survive": "survive", "climb": "climb", "glide": "glide", "swim": "swim",
                     "course": "course", "craft": "crafting", "cook": "cooking", "gather": "gathering",
                     "collect": "gathering", "puzzle": "puzzle", "mount": "mount", "ability_use": "ability",
                     "destroy": "destroy", "deliver": "npc", "talk": "npc", "discover": "exploration",
                     "reach": "exploration", "region": "exploration", "interact": "exploration",
                     "retrieve": "exploration", "open_chest": "exploration", "flag": "story", "event": "story",
                     "ability": "ability"}.get(c, c))
            cond = o.get("conditions", {})
            if cond.get("period") == "night":
                out.add("night")
            if cond.get("weather"):
                out.add("weather")
        for sp in st.get("spawns", []) + q.get("spawns", []):
            k = sp.get("kind")
            if k == "nest":
                weak = sp.get("weak", {"fire": 3.0, "explosion": 4.0})
                out.add("fire" if weak.get("fire", 3.0) > 0 else "explosives")
            if k == "puzzle":
                for el in sp.get("elements", []):
                    out.add({"brazier": "fire", "vane": "wind", "plate": "physics"}.get(el.get("type"), "puzzle"))
            if sp.get("float"):
                out.add("swim")
            if sp.get("snap") == "top":
                out.add("climb")
            if sp.get("conditions", {}).get("period") == "night":
                out.add("night")
            if sp.get("conditions", {}).get("weather"):
                out.add("weather")
            if sp.get("tied"):
                out.add("rescue")
            if k == "course":
                out.add({"glide": "glide", "swim": "swim", "ride": "mount"}.get(sp.get("mode"), "course"))
    for sp in q.get("spawns", []):
        if sp.get("kind") == "course":
            out.add({"glide": "glide", "swim": "swim", "ride": "mount"}.get(sp.get("mode"), "course"))
    return out


def main():
    quests = load()
    md = "--md" in sys.argv
    lines = []
    fail = False

    def say(s=""):
        lines.append(s)

    say("# Quest variety report")
    say()
    say("%d quests: %s" % (len(quests), dict(Counter(q["type"] for q in quests))))
    say()
    # Near-duplicates
    groups = defaultdict(list)
    for q in quests:
        if q.get("repeatable"):
            continue
        giver = q.get("start", "") if str(q.get("start", "")).startswith("talk:") else ""
        groups[(signature(q), q.get("region"))].append(q["id"])
        if giver:
            groups[(signature(q), giver)].append(q["id"])
    dups = {k: v for k, v in groups.items() if len(set(v)) > 1}
    say("## Near-duplicates (same steps, same region or giver)")
    if dups:
        fail = True
        for k, v in dups.items():
            say("- FAIL %s: %s" % (sorted(set(v)), k[1]))
    else:
        say("- none")
    say()
    # Main line
    mains = [q for q in quests if q["type"] == "main"]
    say("## Main line: primary activity per quest")
    prev = None
    repeats = 0
    for q in mains:
        p = primary(q)
        mark = "  (repeat)" if p == prev else ""
        repeats += 1 if p == prev else 0
        say("- %-20s %-10s %s%s" % (q["id"], q["category"], p, mark))
        prev = p
    if repeats > 3:
        fail = True
        say("- FAIL: %d consecutive repeats" % repeats)
    say()
    # Kill share
    kill_only = [q["id"] for q in quests if all(canon(o) in ("kill", "clear", "talk") for st in q["stages"] for o in st["objectives"])]
    say("## Kill-and-report quests: %d (%.0f%%) %s" % (len(kill_only), 100.0 * len(kill_only) / len(quests), kill_only))
    if len(kill_only) > len(quests) * 0.15:
        fail = True
        say("- FAIL: over 15%")
    say()
    # Regions
    say("## Categories per region (non-main)")
    reg = defaultdict(Counter)
    for q in quests:
        if q["type"] != "main":
            reg[q.get("region", "?")][q["category"]] += 1
    for r in sorted(reg):
        say("- %-10s %d quests, %d categories: %s" % (r, sum(reg[r].values()), len(reg[r]), dict(reg[r])))
    say()
    say("## Session length (mobile): %s" % dict(Counter(q.get("duration", "?") for q in quests)))
    say()
    # Mechanics
    used = Counter()
    for q in quests:
        for m in mechanics(q):
            used[m] += 1
    say("## Mechanics the content asks for")
    for m, n in used.most_common():
        say("- %-12s %d" % (m, n))
    wanted = ["climb", "glide", "swim", "combat", "stealth", "fire", "wind", "explosives", "physics", "weather",
              "night", "crafting", "cooking", "mount", "protect", "escort", "survive", "course", "puzzle", "boss", "rescue"]
    missing = [m for m in wanted if used[m] == 0]
    if missing:
        fail = True
        say("- FAIL: never used: %s" % missing)
    say()
    # Rewards
    rk = Counter()
    for q in quests:
        for k in list(q.get("rewards", {}).keys()) + list(q.get("bonus_rewards", {}).keys()):
            rk[k] += 1
        for st in q["stages"]:
            for k in st.get("rewards", {}):
                rk[k] += 1
    say("## Reward kinds: %s" % dict(rk))
    say()
    say("RESULT: %s" % ("FAIL" if fail else "OK"))
    text = "\n".join(lines)
    print(text)
    if md:
        with open(os.path.join(ROOT, "docs", "QUEST_VARIETY.md"), "w", encoding="utf-8") as f:
            f.write(text + "\n")
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
