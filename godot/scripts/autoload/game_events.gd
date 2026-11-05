class_name GameEventsAutoload
extends Node

## Global Event Bus for decoupled communication across systems, UI, and units.
## No direct tight coupling between units and HUD.

signal unit_selected(unit: CharacterBody2D)
signal selection_cleared()
signal units_selection_changed(selected_units: Array[CharacterBody2D])
signal order_issued(order_type: int, target_position: Vector2, target_unit: CharacterBody2D)
signal unit_spawned(unit: CharacterBody2D)
signal unit_killed(unit: CharacterBody2D, killer: CharacterBody2D)
signal objective_updated(objective_id: String, progress: float, is_completed: bool)
signal battle_ended(player_won: bool)
signal camera_pan_requested(target_world_pos: Vector2)
signal game_paused_toggled(is_paused: bool)

enum OrderType {
	MOVE,
	ATTACK_MOVE,
	ATTACK_TARGET,
	STOP,
	HOLD_FIRE
}

enum Faction {
	ALLIED = 0,
	ENEMY = 1,
	NEUTRAL = 2
}

func emit_unit_selected(unit: CharacterBody2D) -> void:
	unit_selected.emit(unit)

func emit_selection_cleared() -> void:
	selection_cleared.emit()

func emit_units_selection_changed(units: Array[CharacterBody2D]) -> void:
	units_selection_changed.emit(units)

func emit_order_issued(order_type: int, target_pos: Vector2, target_unit: CharacterBody2D = null) -> void:
	order_issued.emit(order_type, target_pos, target_unit)

func emit_unit_killed(unit: CharacterBody2D, killer: CharacterBody2D = null) -> void:
	unit_killed.emit(unit, killer)

func emit_objective_updated(id: String, progress: float, completed: bool) -> void:
	objective_updated.emit(id, progress, completed)
