#!/usr/bin/env python3
"""Generates the placeholder item/category icons (white glyphs, tinted in-game
by category color). Replace any file in assets/icons/ with final art of the
same name; nothing else changes.  Run: python3 tools/gen_icons.py
"""
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "icons")

W = 'fill="#ffffff"'
S = 'fill="none" stroke="#ffffff" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"'

GLYPHS = {
    "weapon_club": f'<path {W} d="M70 18 q14 4 12 18 l-40 48 q-6 8 -14 2 l-4 -4 q-6 -8 2 -14 z"/>',
    "weapon_sword": f'<path {W} d="M78 14 l8 8 -44 44 -8 -8 z"/><path {W} d="M26 58 l16 16 -6 6 -16 -16 z"/><path {W} d="M22 72 l6 6 -10 10 -6 -6 z"/>',
    "weapon_spear": f'<path {S} d="M20 80 L70 30"/><path {W} d="M84 16 l-6 26 -8 -12 -12 -8 z"/>',
    "weapon_hammer": f'<path {S} d="M26 82 L58 46"/><path {W} d="M50 22 l28 28 -12 12 -28 -28 z"/>',
    "weapon_rod": f'<path {S} d="M24 84 L62 42"/><circle {W} cx="70" cy="32" r="12"/><path {W} d="M70 10 q10 10 0 18 q-10 -8 0 -18z" opacity="0.8"/>',
    "armor_head": f'<path {W} d="M20 62 q0 -40 30 -42 q30 2 30 42 l-10 0 q-4 -16 -20 -16 q-16 0 -20 16 z"/>',
    "armor_body": f'<path {W} d="M30 18 l12 6 q8 6 16 0 l12 -6 18 16 -10 14 -8 -6 0 42 -44 0 0 -42 -8 6 -10 -14 z"/>',
    "armor_legs": f'<path {W} d="M30 16 h40 l2 40 -10 30 h-14 l2 -30 -4 -14 -4 14 2 30 h-14 l-10 -30 z"/>',
    "armor_accessory": f'<circle {S} cx="50" cy="42" r="20"/><path {W} d="M50 62 l10 14 -10 12 -10 -12 z"/>',
    "mat_wood": f'<rect {W} x="18" y="30" width="64" height="16" rx="8"/><rect {W} x="24" y="54" width="56" height="16" rx="8"/>',
    "mat_fiber": f'<path {S} d="M30 84 q-6 -40 10 -64 M50 84 q0 -40 0 -66 M70 84 q6 -40 -10 -64"/>',
    "mat_stone": f'<path {W} d="M22 70 l10 -34 26 -14 22 18 2 30 -24 12 z"/>',
    "mat_ore": f'<path {W} d="M18 74 l10 -36 30 -16 26 20 -2 32 -32 10 z" opacity="0.55"/><circle {W} cx="44" cy="50" r="8"/><circle {W} cx="62" cy="62" r="6"/>',
    "mat_ingot": f'<path {W} d="M16 70 l14 -26 h44 l14 26 z"/>',
    "mat_sap": f'<path {W} d="M50 14 q28 34 28 50 a28 28 0 0 1 -56 0 q0 -16 28 -50 z"/>',
    "mat_hide": f'<path {W} d="M28 20 q22 10 44 0 q4 18 12 22 q-8 20 -4 40 q-30 -8 -60 0 q4 -20 -4 -40 q8 -4 12 -22 z"/>',
    "mat_fang": f'<path {W} d="M34 16 q32 6 32 30 q-6 28 -26 42 q6 -26 -6 -72 z"/>',
    "mat_plate": f'<path {W} d="M50 12 l32 12 -4 36 -28 26 -28 -26 -4 -36 z"/>',
    "mat_gland": f'<ellipse {W} cx="50" cy="54" rx="26" ry="30"/><circle fill="#000000" opacity="0.25" cx="42" cy="46" r="8"/>',
    "mat_filament": f'<path {S} d="M20 70 q10 -40 20 0 t20 0 t20 -40"/>',
    "mat_gem": f'<path {W} d="M50 12 l26 26 -26 50 -26 -50 z"/>',
    "food_fruit": f'<circle {W} cx="50" cy="58" r="26"/><path {S} d="M50 32 q4 -12 14 -16"/>',
    "food_meat": f'<path {W} d="M30 30 q30 -18 46 8 q12 24 -16 36 q-24 8 -34 -6 q-12 -18 4 -38z"/><circle {W} cx="26" cy="74" r="8"/>',
    "food_mushroom": f'<path {W} d="M16 52 q34 -44 68 0 z"/><rect {W} x="42" y="50" width="16" height="32" rx="6"/>',
    "food_honey": f'<path {W} d="M50 16 l30 17 v34 l-30 17 -30 -17 v-34 z"/>',
    "food_root": f'<path {W} d="M40 18 h20 q4 30 -10 68 q-14 -38 -10 -68z"/><path {S} d="M50 18 q-10 -8 -18 -2 M50 18 q10 -8 18 -2"/>',
    "food_herb": f'<path {W} d="M50 86 q-30 -30 0 -70 q30 40 0 70z"/><path fill="none" stroke="#000" stroke-opacity="0.25" stroke-width="4" d="M50 84 V24"/>',
    "food_pepper": f'<path {W} d="M36 24 q34 4 40 30 q4 26 -30 38 q12 -28 -10 -68z"/><path {S} d="M36 24 q-6 -8 2 -12"/>',
    "food_moss": f'<circle {W} cx="34" cy="62" r="16"/><circle {W} cx="56" cy="52" r="20"/><circle {W} cx="70" cy="68" r="14"/>',
    "food_dish": f'<path {W} d="M14 50 h72 q-4 30 -36 32 q-32 -2 -36 -32z"/><path {S} d="M36 38 q4 -10 0 -18 M52 38 q4 -10 0 -18 M68 38 q4 -10 0 -18"/>',
    "key_seed": f'<path {W} d="M50 14 q30 30 20 56 q-10 16 -20 16 q-10 0 -20 -16 q-10 -26 20 -56z"/><path {W} d="M50 30 q10 12 0 26 q-10 -14 0 -26z" fill-opacity="0.3"/>',
    "key_bloom": "".join(f'<ellipse {W} cx="50" cy="30" rx="10" ry="18" transform="rotate({a} 50 50)"/>' for a in range(0, 360, 60)),
    "tool_bomb": f'<circle {W} cx="46" cy="58" r="26"/><path {S} d="M62 36 q10 -12 20 -8"/><circle {W} cx="84" cy="24" r="5"/>',
    "tool_whetstone": f'<path {W} d="M14 64 l20 -30 h52 l-20 30 z"/>',
    "key_glider": f'<path {W} d="M10 50 q40 -34 80 0 q-40 -12 -80 0z"/><path {S} d="M50 38 V86"/>',
    "key_thread": f'<path {S} d="M16 70 q18 -40 34 -10 t34 -20"/><circle {W} cx="84" cy="40" r="6"/>',
    "key_journal": f'<rect {W} x="24" y="16" width="52" height="68" rx="6"/><path fill="none" stroke="#000" stroke-opacity="0.3" stroke-width="4" d="M36 34 h28 M36 46 h28 M36 58 h18"/>',
}
GLYPHS["cat_weapon"] = GLYPHS["weapon_sword"]
GLYPHS["cat_armor"] = GLYPHS["armor_body"]
GLYPHS["cat_material"] = GLYPHS["mat_ore"]
GLYPHS["cat_food"] = GLYPHS["food_fruit"]
GLYPHS["cat_tool"] = GLYPHS["tool_bomb"]
GLYPHS["cat_key"] = GLYPHS["mat_gem"]


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, body in GLYPHS.items():
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">{body}</svg>\n'
        with open(os.path.join(OUT, name + ".svg"), "w") as f:
            f.write(svg)
    print(f"{len(GLYPHS)} icons")


if __name__ == "__main__":
    main()
