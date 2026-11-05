class_name UnitData
extends Resource

## Data-driven resource defining stats, armor, weapons, and costs for Iron Front units.

enum UnitType {
	COMBAT_ENGINEER,
	RIFLE_SQUAD,
	ANTI_TANK_TEAM,
	SCOUT_CAR,
	MEDIUM_TANK,
	HEAVY_TANK
}

@export_group("Identity")
@export var id: String = "unit_basic"
@export var display_name: String = "Unit"
@export var unit_type: UnitType = UnitType.RIFLE_SQUAD
@export var team: int = 0 # 0: Allied (Green), 1: Axis (Red)
@export var sprite: Texture2D = null

@export_group("Core Stats")
@export var hp: float = 100.0
@export var speed: float = 120.0
@export var damage: float = 25.0
@export var range: float = 250.0
@export var attack_cooldown: float = 1.2 # Reload time in seconds
@export var cost: int = 100

@export_group("Armor & Penetration")
@export var armor_front: float = 20.0
@export var armor_side: float = 10.0
@export var armor_rear: float = 5.0
@export var armor_penetration: float = 20.0

@export_group("Physics & Visuals")
@export var unit_radius: float = 20.0
@export var rotation_speed: float = 3.5
@export var turret_rotation_speed: float = 4.0
@export var projectile_speed: float = 500.0
@export var splash_radius: float = 0.0

# Backwards compatibility getters
var max_health: float:
	get: return hp
var attack_range: float:
	get: return range
var reload_time: float:
	get: return attack_cooldown
var move_speed: float:
	get: return speed
var deployment_cost: int:
	get: return cost
var faction: int:
	get: return team
	set(v): team = v
