class_name MissionData
extends Resource

## Data-driven scenario definition for Iron Front tactical missions.

@export var mission_id: String = "operation_iron_shield"
@export var title: String = "Operation Iron Shield"
@export_multiline var briefing: String = "Enemy armored vanguard is pushing through the valley. Secure the crossroads and eliminate the heavy armor."
@export var map_bounds: Rect2 = Rect2(-1000, -700, 2000, 1400)
@export var player_spawn_points: Array[Vector2] = []
@export var enemy_spawn_points: Array[Vector2] = []
@export var target_capture_points: Array[Vector2] = []
@export var player_unit_ids: Array[String] = ["unit_medium_tank", "unit_infantry", "unit_infantry", "unit_artillery"]
@export var enemy_unit_ids: Array[String] = ["unit_medium_tank", "unit_recon", "unit_infantry", "unit_infantry"]
@export var time_limit_seconds: float = 300.0
