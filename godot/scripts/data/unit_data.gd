class_name UnitData
extends Resource

## Data-driven resource defining attributes, armor, weapons, and movement stats.

enum UnitType {
	INFANTRY,
	RECON_VEHICLE,
	MEDIUM_TANK,
	HEAVY_TANK,
	ARTILLERY
}

@export_group("Identity")
@export var id: String = "unit_basic"
@export var display_name: String = "Basic Unit"
@export var unit_type: UnitType = UnitType.INFANTRY
@export var faction: int = 0 # 0: Allied, 1: Enemy

@export_group("Survivability")
@export var max_health: float = 100.0
@export var armor_front: float = 20.0
@export var armor_side: float = 10.0
@export var armor_rear: float = 5.0

@export_group("Mobility")
@export var move_speed: float = 120.0 # Pixels per second
@export var rotation_speed: float = 3.5 # Radians per second
@export var acceleration: float = 400.0

@export_group("Firepower")
@export var attack_range: float = 250.0
@export var min_attack_range: float = 0.0 # Used for artillery
@export var damage: float = 25.0
@export var armor_penetration: float = 25.0 # Direct counter to target armor
@export var reload_time: float = 1.2 # Seconds between shots
@export var splash_radius: float = 0.0 # Area of effect (for artillery/HE shells)
@export var projectile_speed: float = 450.0
@export var turret_rotation_speed: float = 4.0

@export_group("Perception & Cost")
@export var vision_range: float = 320.0
@export var unit_radius: float = 20.0 # Collision & selection circle
@export var deployment_cost: int = 100
