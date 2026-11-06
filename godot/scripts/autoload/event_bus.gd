class_name EventBus
extends Node

## Central decoupled Signal Bus for Iron Front.
## Facilitates communication across entities, systems, UI, and managers without direct references.

# Selection & Orders
signal unit_selected(unit: CharacterBody2D)
signal selection_cleared()
signal units_selection_changed(selected_units: Array[CharacterBody2D])
signal order_issued(order_type: int, target_position: Vector2, target_unit: CharacterBody2D)

# Economy & Construction
signal supply_changed(current_supply: float, rate_per_sec: float)
signal building_placement_requested(building_res_path: String)
signal building_constructed(building: Node2D)
signal building_destroyed(building: Node2D)
signal building_selected(building: Node2D)
signal production_queue_updated(building: Node2D, queue_items: Array, current_progress: float)
signal supply_crate_collected(amount: float, world_pos: Vector2)
signal node_captured(node: Node2D, faction: int)

# Combat & Lifecycle
signal unit_spawned(unit: CharacterBody2D)
signal unit_damaged(unit: CharacterBody2D, amount: float, is_rear_hit: bool)
signal unit_killed(unit: CharacterBody2D, killer: CharacterBody2D)
signal projectile_fired(start_pos: Vector2, target_pos: Vector2, is_artillery: bool)

# Campaign & Meta
signal objective_updated(objective_id: String, progress: float, is_completed: bool)
signal mission_completed(stars_earned: int, war_bonds_awarded: int)
signal mission_failed(reason: String)
signal upgrade_purchased(upgrade_id: String, branch: String)

# System & Audio
signal play_sfx_requested(sfx_id: String, world_position: Vector2)
signal tactical_pause_toggled(is_paused: bool)
