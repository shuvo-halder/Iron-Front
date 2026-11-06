class_name EnemyAIData
extends Resource

## Data-driven configuration for Iron Front Enemy AI.
## Controls economy, build orders, wave timing, target priorities, and retreat thresholds.

enum Difficulty {
	EASY,
	MEDIUM,
	HARD
}

@export var difficulty: Difficulty = Difficulty.MEDIUM
@export var ai_name: String = "Axis Vanguard Commander"
@export var base_position: Vector2 = Vector2(750, 0)
@export var staging_area: Vector2 = Vector2(450, 0)
@export var base_defense_radius: float = 420.0
@export var player_hq_position: Vector2 = Vector2(-750, 0)

# Economy Multipliers
@export var starting_supply: float = 450.0
@export var passive_supply_rate: float = 16.0
@export var supply_income_multiplier: float = 1.0 # 0.75 on Easy, 1.0 on Medium, 1.35 on Hard

# Build Order (Sequence of unit resource paths to queue)
@export var build_order: Array[String] = [
	"res://resources/units/rifle_squad.tres",
	"res://resources/units/scout_car.tres",
	"res://resources/units/anti_tank_team.tres",
	"res://resources/units/medium_tank.tres",
	"res://resources/units/rifle_squad.tres",
	"res://resources/units/heavy_tank.tres",
	"res://resources/units/attack_helicopter.tres"
]

# Wave Formation Settings
@export var wave_interval_seconds: float = 30.0 # 45s on Easy, 30s on Medium, 20s on Hard
@export var min_wave_size: int = 5              # 3 on Easy, 5 on Medium, 7 on Hard
@export var max_staging_time: float = 40.0      # Force wave if staging takes too long

# Tactical Decisions & Thresholds
@export var retreat_health_threshold: float = 0.35 # Retreat if unit HP < 35%
@export var outnumbered_ratio_threshold: float = 0.40 # Friendly / Enemy strength in 300px
@export var aggressive_chase_range: float = 350.0
@export var prioritize_turrets: bool = true
