extends Node
## Global decoupled signal hub.
##
## Systems emit here instead of holding references to each other. UI, audio,
## save and quests listen. Keep payloads small and data-only.

# --- Player ---------------------------------------------------------------
signal player_spawned(player: Node3D)
signal player_damaged(amount: float, source: Node)
signal player_healed(amount: float)
signal player_died
signal player_respawned
signal player_state_changed(state_name: StringName)
signal stamina_exhausted

# --- Combat ---------------------------------------------------------------
signal hit_landed(position: Vector3, damage: float, is_critical: bool)
signal entity_killed(entity_type_id: StringName, position: Vector3)
signal combat_state_changed(in_combat: bool)
signal perfect_dodge
signal parry_success(position: Vector3)

# --- Items ----------------------------------------------------------------
signal inventory_changed
signal item_acquired(item_id: StringName, count: int)
signal equipment_changed(slot: StringName)
signal weapon_durability_warning(item_id: StringName)
signal weapon_broken(item_id: StringName)
signal recipe_discovered(recipe_id: StringName)

# --- World ----------------------------------------------------------------
## Perception stimulus: anything loud (sprinting, combat, explosions).
signal noise_emitted(position: Vector3, radius: float, source: Node)
signal poi_discovered(poi_id: StringName)
signal region_entered(region_id: StringName)
signal lightning_strike(position: Vector3)
signal explosion(position: Vector3, radius: float)
signal time_period_changed(period: StringName)
signal weather_changed(weather_id: StringName)

# --- UI / meta ------------------------------------------------------------
signal toast(text: String)
signal interact_prompt_changed(prompt_key: String)
signal dialogue_requested(speaker_key: String, lines: PackedStringArray)
signal menu_toggled(open: bool)
## A world station was used: &"campfire" opens cooking / resting.
signal station_opened(station: StringName, node: Node3D)
signal chest_opened(chest_id: String, items: Array)
signal settings_changed
signal game_saved
signal game_loaded
signal quality_changed(level: int)
