class_name MissionData
extends Resource

## Data-driven scenario definition for Iron Front tactical missions.
## Defines victory/loss objectives, starting army compositions, economy,
## enemy AI difficulty profiles, and 3-star performance metrics.

enum ObjectiveType {
	DESTROY_HQ,        # Destroy Axis Headquarters structure
	SURVIVE_TIME,      # Survive for survive_duration_seconds
	DEFEND_BUILDING,   # Protect Allied HQ or designated structure from destruction
	ELIMINATE_ALL      # Eliminate all enemy combat units and buildings
}

@export var mission_index: int = 1
@export var mission_id: String = "mission_01_valley_vanguard"
@export var title: String = "Mission 1: Valley Vanguard"
@export_multiline var briefing: String = "Allied armored command has established a foothold. Breach the Axis valley outpost and destroy their forward Headquarters."
@export var objective_type: ObjectiveType = ObjectiveType.DESTROY_HQ
@export var objective_description: String = "Destroy the Axis Forward Headquarters."

# Tactical Timers
@export var survive_duration_seconds: float = 180.0 # Used for SURVIVE_TIME & DEFEND_BUILDING
@export var par_time_seconds: float = 180.0          # Target completion time for 2-star bonus

# Starting Economy
@export var starting_player_supply: float = 450.0
@export var starting_enemy_supply: float = 400.0

# Starting Player Forces
# Format: Array of { "res_path": String, "offset": Vector2 }
@export var starting_player_units: Array[Dictionary] = []
@export var starting_player_buildings: Array[Dictionary] = []

# Enemy AI Configuration & Starting Forces
@export var enemy_ai_config: EnemyAIData
@export var starting_enemy_units: Array[Dictionary] = []
@export var starting_enemy_buildings: Array[Dictionary] = []

# Rewards & Star Criteria
@export var reward_money: int = 150 # War Bonds awarded on victory
@export var max_allowed_casualties_3_star: int = 4 # Lose <= X units for 3-star mastery
