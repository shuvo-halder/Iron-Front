class_name TestUnitsShowcase
extends Node2D

## Showcase test scene demonstrating all 6 unit types for both teams.

@export var unit_scene: PackedScene = preload("res://scenes/entities/unit.tscn")

const UNIT_PATHS = [
	"res://resources/units/combat_engineer.tres",
	"res://resources/units/rifle_squad.tres",
	"res://resources/units/anti_tank_team.tres",
	"res://resources/units/scout_car.tres",
	"res://resources/units/medium_tank.tres",
	"res://resources/units/heavy_tank.tres"
]

@onready var units_container: Node2D = $UnitsContainer
@onready var labels_container: Node2D = $LabelsContainer

var spawned_units: Array[Unit] = []

func _ready() -> void:
	spawn_showcase()

func spawn_showcase() -> void:
	for u in spawned_units:
		if is_instance_valid(u):
			u.queue_free()
	spawned_units.clear()

	for child in labels_container.get_children():
		child.queue_free()

	# Spawn Team 0 (Allied - Green) on left, Team 1 (Axis - Red) on right
	var start_y := -240.0
	var y_spacing := 95.0

	for i in range(UNIT_PATHS.size()):
		var res_path := UNIT_PATHS[i]
		var y := start_y + i * y_spacing

		# Allied Unit (Team 0)
		var allied_u := _spawn_unit(res_path, Vector2(-220, y), 0)
		# Axis Unit (Team 1)
		var axis_u := _spawn_unit(res_path, Vector2(220, y), 1)

		# Row Label
		var lbl := Label.new()
		lbl.text = allied_u.data.display_name + " (Cost: %d S)" % allied_u.data.cost
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(-150, y - 40)
		lbl.size = Vector2(300, 24)
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
	for u in spawned_units:
		if is_instance_valid(u) and u.data.team == 0 and u.current_state != Unit.State.DEAD:
			u.set_move_target(Vector2(60, u.global_position.y))

func _on_order_axis_attack_pressed() -> void:
	for axis_u in spawned_units:
		if is_instance_valid(axis_u) and axis_u.data.team == 1 and axis_u.current_state != Unit.State.DEAD:
			# Find closest allied unit
			var closest: Unit = null
			var min_dist := INF
			for allied_u in spawned_units:
				if is_instance_valid(allied_u) and allied_u.data.team == 0 and allied_u.current_state != Unit.State.DEAD:
					var d := axis_u.global_position.distance_to(allied_u.global_position)
					if d < min_dist:
						min_dist = d
						closest = allied_u
			if closest:
				axis_u.set_attack_target(closest)

func _on_test_damage_pressed() -> void:
	for u in spawned_units:
		if is_instance_valid(u) and u.current_state != Unit.State.DEAD:
			u.take_damage(25.0, 30.0, Vector2.RIGHT, null)

func _on_reset_showcase_pressed() -> void:
	spawn_showcase()
