"""Quest authoring DSL (see docs/QUESTS.md, "Content Generation Guidelines").

Quests are written as Python dicts with text inline in the 8 shipped
languages. `compile_quest` swaps every piece of text for a generated
localization key and returns plain JSON data; the strings collected in
STRINGS are written to tools/loc_generated.py and merged into
localization/strings.csv by tools/gen_localization.py.

    L(en, es, pt, fr, de, ja, ko, zh)   a piece of text
    T("QO_T_DEFEAT", "NAME_THORNLING")   a shared objective template + args
                                         (args: existing keys or L(...))

Key naming is derived from the position in the quest:
    Q_<ID>            title        Q_<ID>_DESC       description
    Q_<ID>_OF0        offer line   Q_<ID>_S1_TL0     stage 1 talk line
    Q_<ID>_S1_O0_T    objective    Q_<ID>_P2_L0      quest spawn 2, line 0
"""

LANGS = ["en", "es", "pt", "fr", "de", "ja", "ko", "zh"]
STRINGS = {}


class Loc:
    __slots__ = ("vals",)

    def __init__(self, *vals):
        if len(vals) != len(LANGS):
            raise SystemExit("L() needs %d languages, got %d: %r" % (len(LANGS), len(vals), vals[:1]))
        self.vals = [str(v) for v in vals]


def L(en, es, pt, fr, de, ja, ko, zh):
    return Loc(en, es, pt, fr, de, ja, ko, zh)


class T:
    """Objective text from a shared template ("Defeat %s") + arguments."""

    def __init__(self, key, *args):
        self.key = key
        self.args = list(args)


def register(key, loc):
    if key in STRINGS and STRINGS[key] != loc.vals:
        raise SystemExit("localization key reused with different text: " + key)
    STRINGS[key] = loc.vals
    return key


ABBR = {
    "stages": "S", "objectives": "O", "spawns": "P", "lines": "L", "offer_lines": "OF",
    "talk_lines": "TL", "hint_lines": "HL", "start_lines": "SL", "end_lines": "EL",
    "waves": "W", "ambushes": "A", "talk": "K", "elements": "E",
}
RENAME = {"title": "title_key", "desc": "desc_key", "text": "text_key", "prompt": "prompt",
          "hint": "hint_key", "shout": "shout_key", "banner": "title_key"}


def _key_part(k):
    return ABBR.get(k, k.upper())


def _walk(v, path):
    if isinstance(v, Loc):
        return register(path, v)
    if isinstance(v, T):
        raise SystemExit("T() is only valid as an objective 'text': " + path)
    if isinstance(v, list):
        return [_walk(x, "%s%d" % (path, i)) for i, x in enumerate(v)]
    if isinstance(v, dict):
        out = {}
        for k, x in v.items():
            if k == "text" and isinstance(x, T):
                out["text_key"] = x.key
                args = []
                for i, a in enumerate(x.args):
                    args.append(register("%s_A%d" % (path, i), a) if isinstance(a, Loc) else a)
                if args:
                    out["text_args"] = args
                continue
            if isinstance(x, Loc):
                name = RENAME.get(k, k)
                suffix = {"title": "", "desc": "_DESC"}.get(k, "_" + _key_part(k))
                out[name] = register(path + suffix, x)
                continue
            out[k] = _walk(x, path + "_" + _key_part(k))
        return out
    return v


def compile_quest(q):
    return _walk(q, "Q_" + q["id"].upper())


# --- Builders -----------------------------------------------------------------------------------

def quest(qid, qtype, category, region, difficulty, duration, title, desc, stages, rewards=None, **extra):
    q = {"id": qid, "type": qtype, "category": category, "region": region,
         "difficulty": difficulty, "duration": duration, "stages": stages}
    # Existing keys may be passed as plain strings (migrated quests).
    q["title_key" if isinstance(title, str) else "title"] = title
    q["desc_key" if isinstance(desc, str) else "desc"] = desc
    if rewards:
        q["rewards"] = rewards
    q.update(extra)
    return q


def stage(*objectives, spawns=None, talk=None, hint=None, flag=None, **extra):
    s = {"objectives": list(objectives)}
    if spawns:
        s["spawns"] = spawns
    if talk:
        s["talk_lines"] = talk
    if hint:
        s["hint_lines"] = hint
    if flag:
        s["on_complete_flag"] = flag
    s.update(extra)
    return s


def obj(otype, target="", text=None, count=None, **kw):
    o = {"type": otype}
    if target != "":
        o["target"] = target
    if text is not None:
        o["text_key" if isinstance(text, str) else "text"] = text
    if count is not None:
        o["count"] = count
    o.update(kw)
    return o
