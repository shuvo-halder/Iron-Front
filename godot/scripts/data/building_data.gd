class_name BuildingData
extends Resource

## Data-driven resource defining structure stats, cost, footprint, and production capabilities.

enum BuildingCategory {
	COMMAND,
	PRODUCTION,
	DEFENSE,
	RESOURCE
}

@export_group("Identity")
@export var id: String = "building_barracks"
@export var display_name: String = "Barracks"
@export var category: BuildingCategory = BuildingCategory.PRODUCTION
@export var faction: int = 0

@export_group("Stats & Cost")
@export var max_health: float = 600.0
@export var supply_cost: int = 150
@export var build_time_seconds: float = 8.0
@export var grid_footprint: Vector2i = Vector2i(2, 2)

@export_group("Functionality")
@export var supply_income_per_sec: float = 0.0
@export var producible_unit_ids: Array[String] = ["unit_infantry", "unit_antitank"]
@export var vision_range: float = 300.0

@export_group("Defense")
@export var has_turret: bool = false
@export var turret_damage: float = 0.0
@export var turret_range: float = 0.0
@export var turret_fire_rate: float = 0.0
