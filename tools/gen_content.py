#!/usr/bin/env python3
"""Builds the content layer from tools/content/*.py:

  * data/quests/NN_<module>.json   quest definitions (text replaced by keys)
  * entities / items / loot / world POIs / bosses / world events (upserted)
  * tools/loc_generated.py         every new string, 8 languages
  * localization/strings.csv       via tools/gen_localization.py

Run:  python3 tools/gen_content.py
Then Godot re-imports the CSV on the next editor/headless start.
"""
import importlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "content"))

import qdsl  # noqa: E402
from qdsl import Loc  # noqa: E402
import world  # noqa: E402
import ecology  # noqa: E402
import wilds  # noqa: E402
import seas  # noqa: E402
from loc_common import COMMON  # noqa: E402

# Module -> output file. The numeric prefix fixes load order: the main
# line first (journal order, and who speaks first when an NPC has several).
MODULES = [("q_main", "00_main"), ("q_valley", "10_valley"), ("q_forest", "20_forest"),
           ("q_highlands", "30_highlands"), ("q_water", "40_water"), ("q_sea", "45_sea"), ("q_desert", "50_desert"),
           ("q_veil", "60_veil"), ("q_misc", "70_misc"), ("q_bounty", "80_bounty"),
           ("q_vehicles", "90_vehicles")]


def data(p):
    return os.path.join(ROOT, "data", p)


def load(p):
    with open(data(p), encoding="utf-8") as f:
        return json.load(f)


def dump(p, obj, indent):
    with open(data(p), "w", encoding="utf-8") as f:
        f.write(json.dumps(obj, indent=indent, ensure_ascii=True))


def dump_lines(p, entries):
    """One entry per line (hand-edited files stay readable)."""
    with open(data(p), "w", encoding="utf-8") as f:
        f.write("[\n" + ",\n".join("  " + json.dumps(e, ensure_ascii=True) for e in entries) + "\n]\n")


def upsert(lst, entries):
    idx = {e["id"]: i for i, e in enumerate(lst)}
    for e in entries:
        if e["id"] in idx:
            lst[idx[e["id"]]] = e
        else:
            idx[e["id"]] = len(lst)
            lst.append(e)


def strings(d):
    return {k: (v.vals if isinstance(v, Loc) else v) for k, v in d.items()}


def main():
    loc = {}
    ents = load("entities.json")
    new = []
    for d, l in world.NPCS + world.CREATURES + ecology.ENTITIES + wilds.ENTITIES + seas.NPCS + seas.ENTITIES:
        new.append(d)
        loc.update(strings(l))
    upsert(ents, new)
    for e in ents:
        for patches in (wilds.ENTITY_PATCHES, seas.ENTITY_PATCHES):
            for k, v in patches.get(e["id"], {}).items():
                e[k] = dict(e.get(k, {}), **v) if isinstance(v, dict) else v
    clash = world.color_check(ents, {d["id"] for d in new})
    if clash:
        raise SystemExit("placeholder colours too close: " + "; ".join(clash))
    dump("entities.json", ents, 1)

    items = load("items.json")
    new = []
    for d, l in world.ITEMS + ecology.ITEMS + wilds.ITEMS + seas.ITEMS:
        new.append(d)
        loc.update(strings(l))
    upsert(items, new)
    dump("items.json", items, 1)

    loot = load("loot.json")
    loot.update(world.LOOT)
    loot.update(ecology.LOOT)
    loot.update(wilds.LOOT)
    loot.update(seas.LOOT)
    dump("loot.json", loot, 1)

    visuals = load("visuals.json")
    upsert(visuals, ecology.VISUALS + wilds.VISUALS + seas.VISUALS)
    with open(data("visuals.json"), "w", encoding="utf-8") as f:
        f.write("[\n" + ",\n".join(" " + json.dumps(e, ensure_ascii=True) for e in visuals) + "\n]\n")

    regions = load("regions.json")
    for r in regions:
        for k, v in dict(ecology.REGION_SPAWNS.get(r["id"], {}), **wilds.REGION_SPAWNS.get(r["id"], {}), **seas.REGION_SPAWNS.get(r["id"], {})).items():
            r[k] = v
    dump("regions.json", regions, 1)

    cos = load("cosmetics.json")
    upsert(cos, [d for d, _l in wilds.COSMETICS + seas.COSMETICS])
    for _d, l in wilds.COSMETICS + seas.COSMETICS:
        loc.update(strings(l))
    dump_lines("cosmetics.json", cos)
    cook = load("cooking.json")
    specials = cook.get("specials", [])
    upsert(specials, wilds.SPECIALS + seas.SPECIALS)
    cook["specials"] = specials
    dump("cooking.json", cook, 2)
    buffs = load("buffs.json")
    buffs.update(wilds.BUFFS)
    buffs.update(seas.BUFFS)
    with open(data("buffs.json"), "w", encoding="utf-8") as f:
        f.write("{\n" + ",\n".join("  %s: %s" % (json.dumps(k), json.dumps(v)) for k, v in buffs.items()) + "\n}\n")
    fishing = {"waters": dict(wilds.FISHING["waters"], **seas.FISHING)}
    dump("fishing.json", fishing, 1)
    dump_lines("sites.json", wilds.SITES + seas.SITES)
    loc.update(strings(wilds.STRINGS))
    loc.update(strings(seas.STRINGS))

    discs = []
    for d, l in ecology.DISCOVERIES + wilds.DISCOVERIES + seas.DISCOVERIES:
        discs.append(d)
        loc.update(strings(l))
    dump_lines("discoveries.json", discs)
    loc.update(strings(ecology.STRINGS))
    loc.update(strings(ecology.FAUNA))

    w = load("world.json")
    new = []
    for d, l in world.NEW_POIS + wilds.POIS + seas.POIS:
        new.append(d)
        loc.update(strings(l))
    upsert(w["pois"], new)
    for pid, patch in list(world.POI_PATCHES.items()) + list(seas.POI_PATCHES.items()):
        for p in w["pois"]:
            if p["id"] == pid:
                p.update(patch)
    w["islets"] = seas.ISLETS
    dump("world.json", w, 2)

    bosses = load("bosses.json")
    upsert(bosses, world.MINI_BOSSES)
    dump("bosses.json", bosses, 1)
    loc.update(strings(world.BOSS_LOC))

    events = load("world_events.json")
    upsert(events, world.EVENTS)
    dump_lines("world_events.json", events)
    loc.update(strings(world.EVENT_LOC))
    loc.update(strings(world.EXTRA_LOC))

    os.makedirs(data("quests"), exist_ok=True)
    total = 0
    kinds = {}
    for mod_name, out in MODULES:
        mod = importlib.import_module(mod_name)
        compiled = [qdsl.compile_quest(q) for q in mod.QUESTS]
        for q in compiled:
            kinds[q["type"]] = kinds.get(q["type"], 0) + 1
        with open(data("quests/%s.json" % out), "w", encoding="utf-8") as f:
            f.write(json.dumps(compiled, indent=1, ensure_ascii=True))
        total += len(compiled)
    legacy = data("quests.json")
    if os.path.exists(legacy):
        os.remove(legacy)   # migrated into data/quests/

    loc.update(COMMON)
    loc.update(qdsl.STRINGS)
    bad = [k for k, v in loc.items() if len(v) != len(qdsl.LANGS)]
    if bad:
        raise SystemExit("wrong language count: " + ", ".join(bad))
    with open(os.path.join(HERE, "loc_generated.py"), "w", encoding="utf-8") as f:
        f.write("# Generated by tools/gen_content.py from tools/content/*.py - do not edit.\n")
        f.write("GENERATED = {\n")
        for k in sorted(loc):
            f.write("    %s: %s,\n" % (json.dumps(k), json.dumps(loc[k], ensure_ascii=False)))
        f.write("}\n")
    print("%d quests %s, %d generated strings" % (total, kinds, len(loc)))
    import gen_localization
    gen_localization.main()


if __name__ == "__main__":
    main()
