@tool
class_name UiAutoTweenProperty extends Control

@export var target_property: StringName = &"property"
@export var animate_in_editor: bool = true
@export var scale_target: Vector2 = Vector2(1.2, 1.2)
@export var rotation_degrees_target: float = 15.0
@export var scale_in_duration_x: float = 0.1
@export var scale_in_duration_y: float = 0.15
@export var scale_out_duration_x: float = 0.2
@export var scale_out_duration_y: float = 0.3
@export var rotation_in_duration: float = 0.1
@export var rotation_out_duration: float = 0.1
@export var scale_out_delay_x: float = 0.2
@export var scale_out_delay_y: float = 0.25
@export var rotation_out_delay: float = 0.15

var tween: Tween
var base_scale: Vector2
var base_rotation_degrees: float = 0.0
var has_base_state: bool = false


func _ready() -> void:
	cache_base_state()
	pivot_offset = size / 2.0
	resized.connect(update_pivot)


func _set(property: StringName, value: Variant) -> bool:
	if property != target_property:
		return false

	if get(property) == value:
		return false

	if Engine.is_editor_hint() and not animate_in_editor:
		return false

	animate()
	return false


func animate() -> void:
	if not is_inside_tree():
		return

	cache_base_state()
	pivot_offset = size / 2.0
	kill_tween()

	var rotation_target := base_rotation_degrees + rotation_degrees_target * get_random_direction()

	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale:x", base_scale.x * scale_target.x, scale_in_duration_x)
	tween.parallel().tween_property(self, "scale:y", base_scale.y * scale_target.y, scale_in_duration_y)
	tween.parallel().tween_property(self, "rotation_degrees", rotation_target, rotation_in_duration)
	tween.parallel().tween_property(self, "scale:x", base_scale.x, scale_out_duration_x).set_delay(scale_out_delay_x)
	tween.parallel().tween_property(self, "scale:y", base_scale.y, scale_out_duration_y).set_delay(scale_out_delay_y)
	tween.parallel().tween_property(self, "rotation_degrees", base_rotation_degrees, rotation_out_duration).set_delay(rotation_out_delay)


func update_pivot() -> void:
	pivot_offset = size / 2.0


func cache_base_state() -> void:
	if has_base_state:
		return

	base_scale = scale
	base_rotation_degrees = rotation_degrees
	has_base_state = true


func get_random_direction() -> float:
	if randf() < 0.5:
		return -1.0
	return 1.0


func kill_tween() -> void:
	if tween != null and tween.is_running():
		tween.kill()
