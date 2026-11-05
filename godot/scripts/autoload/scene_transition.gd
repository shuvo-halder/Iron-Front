class_name SceneTransitionManager
extends CanvasLayer

## Global Scene Transition Autoload Singleton with black fade animation.
## Blocks touchscreen input during transitions to prevent duplicate clicks.

signal transition_started
signal scene_loaded
signal transition_finished

@onready var color_rect: ColorRect = $ColorRect if has_node("ColorRect") else null

var _is_transitioning: bool = false
const DEFAULT_FADE_TIME: float = 0.35

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not color_rect:
		color_rect = ColorRect.new()
		color_rect.name = "ColorRect"
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_rect.color = Color(0, 0, 0, 0)
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(color_rect)

func change_scene(target_scene_path: String, duration: float = DEFAULT_FADE_TIME) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	transition_started.emit()

	# Block touch inputs during transition
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fade to Black
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	await tween.finished

	# Change Scene
	var err := get_tree().change_scene_to_file(target_scene_path)
	if err != OK:
		push_error("SceneTransition: Failed to load scene: %s (Error %d)" % [target_scene_path, err])
	scene_loaded.emit()

	# Small pause for mobile garbage cleanup
	await get_tree().create_timer(0.05).timeout

	# Fade from Black
	var fade_in_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	fade_in_tween.tween_property(color_rect, "color:a", 0.0, duration)
	await fade_in_tween.finished

	# Unblock touch inputs
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_finished.emit()

func fade_to_black(duration: float = DEFAULT_FADE_TIME) -> void:
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	await tween.finished

func fade_from_black(duration: float = DEFAULT_FADE_TIME) -> void:
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	await tween.finished
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
