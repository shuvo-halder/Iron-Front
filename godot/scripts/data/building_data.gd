class_name BuildingData
extends Resource

## Data-driven resource defining structure stats, cost, footprint, and production capabilities.

enum BuildingType {
	HQ,
	BARRACKS,
	FACTORY,
	TURRET
}

@export_group("Identity")
@export var id: String = "building_hq"
@export var display_name: String = "Headquarters"
@export var building_type: BuildingType = BuildingType.HQ
@export var faction: int = 0 # 0: Allied, 1: Axis

@export_group("Stats & Cost")
@export var max_health: float = 1200.0
@export var supply_cost: int = 400
@export var build_time: float = 10.0
@export var footprint_radius: float = 48.0
@export var building_color: Color = Color(0.2, 0.7, 0.4)

@export_group("Production & Economy")
@export var passive_supply_rate: float = 10.0 ## Passive income in supply/sec
@export var producible_unit_paths: Array[String] = []

@export_group("Defense Turret")
@export var is_defense_turret: bool = false
@export var turret_damage: float = 45.0
@export var turret_range: float = 300.0
@export var turret_cooldown: float = 1.2
@export var can_target_air: bool = true ## Turrets shoot surface-to-air rockets
