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

# --- Quests / progression ---------------------------------------------------
signal npc_talked(npc_id: StringName)
signal quest_started(quest_id: StringName)
signal quest_updated(quest_id: StringName)
signal quest_stage_advanced(quest_id: StringName, stage: int)
signal quest_completed(quest_id: StringName)
signal quest_failed(quest_id: StringName, reason: String)
## Rewards actually granted (after the duplicate guard): {items, glimmer, jade...}
signal rewards_granted(source: String, rewards: Dictionary)
signal jade_changed(total: int)
# Gameplay facts quests listen to (emitted by the systems that own them)
signal resource_gathered(node_type: StringName, position: Vector3)
signal item_crafted(item_id: StringName)
signal dish_cooked(item_id: StringName)
signal creature_defeated(entity_id: StringName, group_id: String, sneak: bool)
## Quest-world objects: clues, levers, captives, relics, nests, ring courses.
signal quest_object_used(object_id: StringName, group: StringName)
signal quest_object_destroyed(object_id: StringName, group: StringName)
signal encounter_finished(encounter_id: StringName, success: bool)
signal course_finished(course_id: StringName, seconds: float)
## Live encounter / challenge banner (title "" hides it): "Survive · 0:42".
signal encounter_hud(title: String, detail: String, ratio: float)
## World objects asking the HUD for a panel: &"board" (bounties, arg = board
## id), &"altar" (Warden altar: jade upgrades and cosmetics).
signal panel_requested(panel: StringName, arg: String)
## Free-form scripted beats: data can wait for any named event.
signal quest_event(name: StringName)
signal flag_set(flag: StringName)
signal ability_unlocked(ability_id: StringName)
signal ability_used(ability_id: StringName)
signal boss_engaged(boss_id: StringName, node: Node3D)
signal boss_phase_changed(boss_id: StringName, phase: int)
signal boss_defeated(boss_id: StringName)
signal boss_disengaged(boss_id: StringName)
signal mount_tamed(mount_id: StringName)
signal mount_changed(mounted: bool)
signal vehicle_acquired(vehicle_id: StringName, source: String)
signal vehicle_changed(driving: bool)
signal vehicle_mode_changed(mode: StringName)   # land_mode | water_mode
signal world_event_started(event_id: StringName, position: Vector3)
signal world_event_ended(event_id: StringName)
## Big centred title card (discoveries, quests, bosses): title, subtitle.
signal title_card(title: String, subtitle: String)
signal discovery_made(discovery_id: StringName)
signal quality_changed(level: int)
