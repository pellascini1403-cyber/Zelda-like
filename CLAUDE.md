# Project rules (Veloria, Godot 4.4)

## Characters: real 3D models, never code primitives
- Final main characters and human NPCs are **real rigged 3D models** (anatomy, modelled face, ears, hands, feet, hair geometry, clothes with folds, materials, skeleton, animations), integrated through `docs/CHARACTER_PIPELINE.md` (`CharacterModel`, `SpringBoneChain`, `EntityVisual._build_model`).
- **Never** try to reach a final or professional character with code primitives: capsules, cylinders, spheres, elliptical segments, tubes, separate pieces or simple procedural meshes.
- `src/entities/mannequin_builder.gd` is a **frozen technical placeholder** ("PLACEHOLDER — DISEÑO FINAL PENDIENTE"). Keep it working for gameplay tests; do not refine its look.
- Don't invent final designs of characters, enemies or creatures; the user delivers them.
- The environment (lighting, materials, vegetation, water, terrain, atmosphere, architecture, VFX) keeps being developed in code.

## World
- Natural oriental fantasy, no technology or modern elements. The Vantrel vehicles, depot and garage were removed on purpose; don't reintroduce vehicles.

## Workflow
- Reports to the user are in Spanish. Never call the project "finished".
- 8 languages (en, es, pt, fr, de, ja, ko, zh). Content and loc: `python3 tools/gen_content.py`.
- Tests must stay green and are never weakened:
  ```
  godot --headless -- --unit
  godot --headless -- --smoke
  godot --headless -- --systems
  ```
- Validate a character model with `godot --headless -- --check-model res://path.glb ENTITY_ID`.
- Mobile-first. Extend the architecture, don't rewrite it.
