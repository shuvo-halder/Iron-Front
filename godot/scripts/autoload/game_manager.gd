class_name GameManager
extends Node

## Controls game state machine, active mission flow, and live player economy.

enum GameState {
	BOOT,
	MAIN_MENU,
	UPGRADE_SHOP,
	MISSION_BRIEFING,
	IN_GAME,
	PAUSED,
	VICTORY,
	DEFEAT
}

var current_state: GameState = GameState.BOOT
var current_mission_id: String = "mission_01"

# Economy State
var current_supply: float = 250.0
var base_income_rate: float = 6.0 # Supply per second
var captured_node_count: int = 0
const NODE_INCOME_RATE: float = 4.0
const MAX_SUPPLY_CAP: float = 1200.0

# Unit population
const MAX_ACTIVE_UNITS: int = 100
var active_allied_units: int = 0
var active_axis_units: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if current_state == GameState.IN_GAME and not get_tree().paused:
		_tick_economy(delta)

func _tick_economy(delta: float) -> void:
	var total_rate: float = base_income_rate + (captured_node_count * NODE_INCOME_RATE)
	current_supply = minf(current_supply + (total_rate * delta), MAX_SUPPLY_CAP)
	
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.supply_changed.emit(current_supply, total_rate)

func can_afford(cost: float) -> bool:
	return current_supply >= cost

func spend_supply(cost: float) -> bool:
	if can_afford(cost):
		current_supply -= cost
		var bus = get_node_or_null("/root/EventBus")
		if bus:
			bus.supply_changed.emit(current_supply, get_current_income_rate())
		return true
	return false

func get_current_income_rate() -> float:
	return base_income_rate + (captured_node_count * NODE_INCOME_RATE)

func register_node_capture(is_player: bool) -> void:
	if is_player:
		captured_node_count += 1
	else:
		captured_node_count = maxi(0, captured_node_count - 1)

func set_state(new_state: GameState) -> void:
	current_state = new_state
	match current_state:
		GameState.PAUSED:
			get_tree().paused = true
		GameState.IN_GAME:
			get_tree().paused = false
		GameState.VICTORY, GameState.DEFEAT:
			get_tree().paused = false
