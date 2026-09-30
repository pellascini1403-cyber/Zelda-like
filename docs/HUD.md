# In-game HUD: definitive art and palette

The in-game HUD uses the user's final PNGs directly. They are cropped pixel-exact from the delivered sheets and never redrawn, recoloured or approximated.

- **Assets:** `assets/ui/hud/` (imported with mipmaps so they scale down cleanly).
- **Code:** `HudArt` (`src/ui/hud_art.gd`) holds the textures, the palette and the reference sizes.

## Palette (HUD only)

| Token | Value | Use |
|---|---|---|
| `CELESTE` | `#4EF0FC` | hearts, compass centre, quest diamond, progress fills |
| `WHITE` | `#FFFFFF` | text, icons, compass letters and markers |
| `BLACK` | `#000000` | text outline |
| `SHADE` | black at 20 % | pills, discs, lost hearts, panels |

No other colours, gradients, borders or ornaments are used in the HUD overlay. The 3D world (including world-space labels such as a traveller's "Help!") keeps its own colours.

## Elements

The layout is measured on the reference at 1280×720, with the standard 24/16 safe margins.

| Element | PNG | Placement | Behaviour |
|---|---|---|---|
| **Hearts** (`HeartRow`, replaces `SegmentBar`) | `heart.png` | 37 px wide, 49 px pitch, from (38, 29); 6 per row | 1 heart = 20 HP. A lost heart is the same PNG in black at 20 %; a partly lost heart shows its lost part that way. |
| **Compass** (`Compass`) | `compass_bar.png` (567×57 at y 29) and `compass_center.png` (20 px at y 7) | the centre marker sits on the exact screen centre | Keeps its heading logic. Cardinal letters and markers (discovered places, pin, event beacon) are white. The tracked objective uses the quest diamond, with its distance. |
| **Buttons** (`GlyphButton`) | `btn_map/journal/bag/pause.png` | 57 px, 13 px gap, from y 29, ending 46 px from the right edge | Same tabs, sound and press animation as before. |
| **Quest indicator** (`QuestTracker`) | `quest_diamond.png` | 18 px, before each objective under the buttons | Shows and hides with the tracked quest as before. A finished objective keeps the diamond in black at 20 %. |

## Other HUD pieces moved to the palette

- **Status line, buffs, jade count, toasts, item feed:** white text with a black outline.
- **Stamina ring:** celeste on a black-20 % track; white when exhausted.
- **Ability indicator and touch buttons:** black-20 % discs with white glyphs; a celeste ring while pressed. The badge is celeste when it reads "!", otherwise black.
- **Title card, reward card, encounter banner, boss plate:**
  - black-20 % bands or cards;
  - titles in white, headings in celeste;
  - bars with a celeste fill on a black-20 % track.
- **Dialogue box:** black-20 % panel with a celeste speaker name.
- **Screen feedback:**
  - the damage vignette is black;
  - the cold vignette and the perfect-dodge flash are celeste;
  - the parry flash is white.

## Removed

- **Clock/weather label (top right):** it does not appear in the reference.

## Out of scope

Full-screen menus (inventory, map, journal, settings, shop and so on) keep their previous look for now.

## Captures

`docs/captures/hud/`: `reference_vs_game.png` shows the reference (top) and the game (bottom).
