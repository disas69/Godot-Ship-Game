class_name UiTweenButton extends Button

signal hover_started
signal hover_ended

@export_group("Hover")
@export var hover_animate: bool = true
@export var hover_scale: float = 1.2
@export var scale_with_width: bool = true
@export var width_for_full_scale: float = 160.0
@export var hover_rotation_degrees: float = 5.0
@export var hover_duration_x: float = 0.2
@export var hover_duration_y: float = 0.35
@export var hover_rotation_duration: float = 0.1

@export_group("Press")
@export var press_animate: bool = true
@export var press_scale: float = 0.94
@export var press_duration: float = 0.08

@export_group("Feedback")
@export var silent: bool = true
@export var hover_sfx_key: String = ""
@export var press_sfx_key: String = ""
@export var joy_vibration_device: int = -1
@export var hover_vibration_strength: float = 0.25
@export var hover_vibration_duration: float = 0.1
@export var press_vibration_strength: float = 0.35
@export var press_vibration_duration: float = 0.08

var tween: Tween
var is_hovering: bool = false
var base_scale: Vector2
var base_rotation_degrees: float = 0.0


func _ready() -> void:
	base_scale = get_stable_base_scale()
	base_rotation_degrees = rotation_degrees
	pivot_offset = size / 2.0

	mouse_entered.connect(hover)
	mouse_exited.connect(unhover)
	focus_entered.connect(hover)
	focus_exited.connect(unhover)
	button_down.connect(press)
	button_up.connect(release)
	resized.connect(update_pivot)


func hover() -> void:
	if disabled:
		return

	is_hovering = true
	hover_started.emit()
	play_feedback(hover_sfx_key, hover_vibration_strength, hover_vibration_duration)
	animate_to_hover()


func animate_to_hover() -> void:
	refresh_base_scale_if_ready()
	pivot_offset = size / 2.0
	var scale_ratio := get_width_scale_ratio()
	var scale_target := Vector2.ONE * (1.0 + (hover_scale - 1.0) * scale_ratio)
	var rotation_target := base_rotation_degrees + hover_rotation_degrees * scale_ratio * get_random_direction()

	if not hover_animate:
		return

	kill_tween()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale:x", base_scale.x * scale_target.x, hover_duration_x)
	tween.parallel().tween_property(self, "scale:y", base_scale.y * scale_target.y, hover_duration_y)
	tween.parallel().tween_property(self, "rotation_degrees", rotation_target, hover_rotation_duration)
	tween.parallel().tween_property(self, "rotation_degrees", base_rotation_degrees, hover_rotation_duration).set_delay(hover_rotation_duration)


func unhover() -> void:
	if disabled:
		return

	is_hovering = false
	hover_ended.emit()

	if not hover_animate:
		return

	animate_to_base()


func press() -> void:
	if disabled:
		return

	play_feedback(press_sfx_key, press_vibration_strength, press_vibration_duration)

	if not press_animate:
		return

	refresh_base_scale_if_ready()
	pivot_offset = size / 2.0
	kill_tween()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", base_scale * press_scale, press_duration)
	tween.parallel().tween_property(self, "rotation_degrees", base_rotation_degrees, press_duration)


func release() -> void:
	if disabled or not press_animate:
		return

	if is_hovering and hover_animate:
		animate_to_hover()
	else:
		animate_to_base()


func animate_to_base() -> void:
	refresh_base_scale_if_ready()
	pivot_offset = size / 2.0
	kill_tween()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale:x", base_scale.x, hover_duration_x)
	tween.parallel().tween_property(self, "scale:y", base_scale.y, hover_duration_y)
	tween.parallel().tween_property(self, "rotation_degrees", base_rotation_degrees, hover_rotation_duration)


func update_pivot() -> void:
	pivot_offset = size / 2.0


func get_width_scale_ratio() -> float:
	if not scale_with_width or is_zero_approx(size.x):
		return 1.0

	return clampf(width_for_full_scale / size.x, 0.5, 1.0)


func get_random_direction() -> float:
	if randf() < 0.5:
		return -1.0
	return 1.0


func get_stable_base_scale() -> Vector2:
	if is_zero_approx(scale.x) or is_zero_approx(scale.y):
		return Vector2.ONE
	return scale


func refresh_base_scale_if_ready() -> void:
	if is_zero_approx(base_scale.x) or is_zero_approx(base_scale.y):
		base_scale = get_stable_base_scale()


func play_feedback(sfx_key: String, vibration_strength: float, vibration_duration: float) -> void:
	if silent:
		return

	if not sfx_key.is_empty():
		AudioManager.play(sfx_key)

	if joy_vibration_device >= 0 and vibration_duration > 0.0:
		Input.start_joy_vibration(joy_vibration_device, vibration_strength, vibration_strength, vibration_duration)


func kill_tween() -> void:
	if tween != null and tween.is_running():
		tween.kill()
