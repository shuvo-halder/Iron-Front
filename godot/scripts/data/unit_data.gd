class_name UnitData
extends Resource

## Data-driven resource defining stats, armor, weapons, and costs for Iron Front units.
## Includes Armor Types, Damage Types, and Projectile Types with strict combat multipliers.

enum UnitType {
	COMBAT_ENGINEER,
	RIFLE_SQUAD,
	ANTI_TANK_TEAM,
	SCOUT_CAR,
	MEDIUM_TANK,
	HEAVY_TANK,
	ATTACK_HELICOPTER,
	DEFENSE_TURRET
}

enum ArmorType {
	INFANTRY,
	VEHICLE,
	AIR
}

enum DamageType {
	KINETIC,         ## Small arms, machine guns, autocannons
	EXPLOSIVE,       ## Rockets, missiles, artillery, mortars
	ARMOR_PIERCING   ## Tank high-velocity cannons, anti-tank rounds
}

enum ProjectileType {
	BULLET,          ## Fast tracer, single target
	ROCKET,          ## Medium speed, smoke trail, splash AoE, anti-air capable
	TANK_SHELL       ## High velocity, kinetic punch, small shockwave
}

@export_group("Identity")
@export var id: String = "unit_basic"
@export var display_name: String = "Unit"
@export var unit_type: UnitType = UnitType.RIFLE_SQUAD
@export var team: int = 0 # 0: Allied (Green), 1: Axis (Red)
@export var sprite: Texture2D = null

@export_group("Combat Typing")
@export var armor_type: ArmorType = ArmorType.INFANTRY
@export var damage_type: DamageType = DamageType.KINETIC
@export var projectile_type: ProjectileType = ProjectileType.BULLET
@export var can_target_air: bool = false ## True for Rocket Soldiers (Anti-Tank Team) & Turrets

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
@export var projectile_speed: float = 550.0
@export var splash_radius: float = 0.0

## Returns the damage multiplier based on damage type vs target armor type.
## Air units (Helicopters) take 0 damage from Kinetic and Armor Piercing.
static func get_damage_multiplier(dmg_type: DamageType, arm_type: ArmorType) -> float:
	match arm_type:
		ArmorType.INFANTRY:
			match dmg_type:
				DamageType.KINETIC:
					return 1.5   # Lethal anti-personnel
				DamageType.EXPLOSIVE:
					return 1.1   # Effective splash damage
				DamageType.ARMOR_PIERCING:
					return 0.65  # Over-penetrates soft targets
		ArmorType.VEHICLE:
			match dmg_type:
				DamageType.KINETIC:
					return 0.25  # Ineffective vs armor plate
				DamageType.EXPLOSIVE:
					return 1.35  # Shaped-charge hull damage
				DamageType.ARMOR_PIERCING:
					return 1.5   # Dedicated anti-armor cannon
		ArmorType.AIR:
			match dmg_type:
				DamageType.EXPLOSIVE:
					return 1.6   # Anti-air surface-to-air missiles
				DamageType.KINETIC:
					return 0.0   # Helicopters immune to small arms / non-AA
				DamageType.ARMOR_PIERCING:
					return 0.0   # Tank shells cannot track/hit airborne targets
	return 1.0

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
