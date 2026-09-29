#!/usr/bin/env python3
"""Builds localization/strings.csv (imported by Godot as 8 translations).

Source of truth for text lives in tools/loc_ui.py, tools/loc_content.py,
tools/loc_items.py and tools/loc_world2.py. Run after editing them:  python3 tools/gen_localization.py
"""
import csv
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from loc_ui import UI  # noqa: E402
from loc_content import CONTENT  # noqa: E402
from loc_items import ITEMS  # noqa: E402
from loc_world2 import WORLD2  # noqa: E402

LANGS = ["en", "es", "pt", "fr", "de", "ja", "ko", "zh"]


def main() -> None:
    rows = {}
    for table in (UI, CONTENT, WORLD2):
        for key, values in table.items():
            rows[key] = values
    for item_id, (names, descs) in ITEMS.items():
        base = "ITEM_" + item_id.upper()
        rows[base] = names
        rows[base + "_DESC"] = descs
    bad = [k for k, v in rows.items() if len(v) != len(LANGS)]
    if bad:
        raise SystemExit("wrong column count: " + ", ".join(bad))
    out_dir = os.path.join(HERE, "..", "localization")
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "strings.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["keys"] + LANGS)
        for key in sorted(rows):
            w.writerow([key] + rows[key])
    print(f"{len(rows)} keys x {len(LANGS)} languages")


if __name__ == "__main__":
    main()
