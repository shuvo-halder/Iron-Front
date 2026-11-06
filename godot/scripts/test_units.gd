class_name TestUnitsShowcase
extends Node2D

## Showcase test scene demonstrating all 7 unit types, auto-targeting,
## ballistic projectile pooling, damage types vs armor, and anti-air rules.

@export var unit_scene: PackedScene = preload("res://scenes/entities/unit.tscn")

const UNIT_PATHS = [
	"res://resources/units/combat_engineer.tres",
	"res://resources/units/rifle_squad.tres",
	"res://resources/units/anti_tank_team.tres",
	"res://resources/units/scout_car.tres",
	"res://resources/units/medium_tank.tres",
	"res://resources/units/heavy_tank.tres",
	"res://resources/units/attack_helicopter.tres"
]

@onready var units_container: Node2D = $UnitsContainer
@onready var labels_container: Node2D = $LabelsContainer

var spawned_units: Array[Unit] = []

func _ready() -> void:
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.unit_killed.connect(_on_unit_killed_log)
		bus.unit_damaged.connect(_on_unit_damaged_log)
	spawn_showcase()

func spawn_showcase() -> void:
	for u in spawned_units:
		if is_instance_valid(u):
			u.queue_free()
	spawned_units.clear()

	for child in labels_container.get_children():
		child.queue_free()

	# Spawn Team 0 (Allied - Green) on left, Team 1 (Axis - Red) on right
	var start_y := -270.0
	var y_spacing := 85.0

	for i in range(UNIT_PATHS.size()):
		var res_path := UNIT_PATHS[i]
		var y := start_y + i * y_spacing

		# Allied Unit (Team 0)
		var allied_u := _spawn_unit(res_path, Vector2(-240, y), 0)
		# Axis Unit (Team 1)
		var axis_u := _spawn_unit(res_path, Vector2(240, y), 1)

		# Row Label
		var lbl := Label.new()
		var type_str := "INF"
		if allied_u.data:
			match allied_u.data.armor_type:
				UnitData.ArmorType.INFANTRY: type_str = "INF"
				UnitData.ArmorType.VEHICLE: type_str = "VEH"
				UnitData.ArmorType.AIR: type_str = "AIR"
		lbl.text = "[%s] %s (Cost: %d)" % [type_str, allied_u.data.display_name, allied_u.data.cost]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(-180, y - 36)
		lbl.size = Vector2(360, 24)
		labels_container.add_child(lbl)

func _spawn_unit(path: String, pos: Vector2, team_id: int) -> Unit:
	var u: Unit = unit_scene.instantiate() as Unit
	var base_data := load(path) as UnitData
	var dup_data := base_data.duplicate(true) as UnitData
	dup_data.team = team_id
	u.data = dup_data
	u.global_position = pos
	if team_id == 1:
		u.rotation = PI # Face left toward allies
	units_container.add_child(u)
	spawned_units.append(u)
	return u

func _on_order_allies_advance_pressed() -> void:
	# Advance allies into weapon range; auto-targeting engages automatically!
	for u in spawned_units:
		if is_instance_valid(u) and u.data.team == 0 and u.current_state != Unit.State.DEAD:
			u.order_attack_move(Vector2(60, u.global_position.y))

func _on_order_axis_attack_pressed() -> void:
	# Order Axis units to attack
	for axis_u in spawned_units:
		if is_instance_valid(axis_u) and axis_u.data.team == 1 and axis_u.current_state != Unit.State.DEAD:
			var closest: Unit = null
			var min_dist := INF
			for allied_u in spawned_units:
				if is_instance_valid(allied_u) and allied_u.data.team == 0 and allied_u.current_state != Unit.State.DEAD:
					if axis_u.can_target(allied_u):
						var d := axis_u.global_position.distance_to(allied_u.global_position)
						if d < min_dist:
							min_dist = d
							closest = allied_u
			if closest:
				axis_u.set_attack_target(closest)

func _on_test_auto_target_pressed() -> void:
	# Keep all units IDLE but close the gap by 80px so they enter weapon range
	for u in spawned_units:
		if is_instance_valid(u) and u.current_state != Unit.State.DEAD:
			if u.data.team == 0:
				u.global_position.x += 70.0
			else:
				u.global_position.x -= 70.0
			u.current_state = Unit.State.IDLE
	# Units will scan, acquire target, and open fire automatically!

func _on_test_helicopter_anti_air_pressed() -> void:
	# Test Helicopter rules:
	# 1. Rifle squad tries to target Helicopter -> cannot target!
	# 2. Rocket Soldier (Anti-Tank Team) targets Helicopter -> fires tracking anti-air rocket!
	for u in spawned_units:
		if is_instance_valid(u) and u.data.unit_type == UnitData.UnitType.ATTACK_HELICOPTER and u.data.team == 1:
			var heli: Unit = u
			# Find allied rifle squad and rocket soldier
			for ally in spawned_units:
				if is_instance_valid(ally) and ally.data.team == 0:
					if ally.data.unit_type == UnitData.UnitType.RIFLE_SQUAD:
						print("Rifle squad can target heli: ", ally.can_target(heli)) # Should be false!
						ally.order_attack_target(heli)
					elif ally.data.unit_type == UnitData.UnitType.ANTI_TANK_TEAM:
						print("Rocket soldier can target heli: ", ally.can_target(heli)) # Should be true!
						ally.order_attack_target(heli)

func _on_test_damage_pressed() -> void:
	for u in spawned_units:
		if is_instance_valid(u) and u.current_state != Unit.State.DEAD:
			# Kinetic bullet damage vs unit's armor
			u.take_damage(30.0, 25.0, Vector2.RIGHT, null, UnitData.DamageType.KINETIC)

func _on_reset_showcase_pressed() -> void:
	spawn_showcase()

func _on_unit_killed_log(victim: CharacterBody2D, killer: CharacterBody2D) -> void:
	var v_name := victim.name
	var k_name := killer.name if killer else "Environment/Splash"
	print("[COMBAT EVENT] Unit Killed: ", v_name, " by ", k_name)

func _on_unit_damaged_log(victim: CharacterBody2D, amount: float, is_rear_hit: bool) -> void:
	print("[COMBAT EVENT] Unit Damaged: ", victim.name, " for ", amount, " HP (Rear Hit: ", is_rear_hit, ")")
