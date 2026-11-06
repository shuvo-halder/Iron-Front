class_name SupplyCrate
extends Area2D

## Battlefield supply airdrop crate.
## Allied units can collect it to instantly gain +75 supply resources.

@export var supply_value: float = 75.0

var bob_timer: float = 0.0
var base_y: float = 0.0

func _ready() -> void:
	add_to_group("supply_crates")
	base_y = position.y
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	bob_timer += delta * 3.0
	position.y = base_y + sin(bob_timer) * 3.5
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body is Unit and body.faction == 0 and not body.is_dead:
		_collect(body)

func _collect(_collector: Unit) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("add_supply"):
		gm.add_supply(supply_value)

	var pool = get_node_or_null("/root/ObjectPool")
	if pool:
		pool.spawn_explosion(global_position, 0.6, false)

	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.supply_crate_collected.emit(supply_value, global_position)

	queue_free()

func _draw() -> void:
	# Wooden crate box with reinforced brass corners
	var w := 24.0
	var h := 20.0
	var rect := Rect2(-w * 0.5, -h * 0.5, w, h)
	draw_rect(rect, Color(0.65, 0.45, 0.2))
	draw_rect(rect, Color(0.2, 0.15, 0.1), false, 2.0)

	# Cross braces
	draw_line(rect.position, rect.end, Color(0.4, 0.28, 0.12), 2.0)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y), Color(0.4, 0.28, 0.12), 2.0)

	# Golden supply star / stencil
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.85, 0.2))

	# Soft glowing beacon
	var alpha := 0.25 + sin(bob_timer * 2.0) * 0.15
	draw_arc(Vector2.ZERO, 18.0, 0, TAU, 20, Color(1.0, 0.9, 0.3, alpha), 2.0)
