class_name SceneTransition extends CanvasLayer

@export var transition_rect: ColorRect
@export var fade_in_duration := 0.45
@export var fade_out_duration := 0.45

var shader_material: ShaderMaterial
var active_tween: Tween


func _ready() -> void:
	layer = 128
	visible = false
	if transition_rect == null:
		push_warning("SceneTransition: transition_rect is not assigned.")
		return

	transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	shader_material = transition_rect.material as ShaderMaterial
	if shader_material == null:
		push_warning("SceneTransition: transition_rect material is not a ShaderMaterial.")
		return

	shader_material = shader_material.duplicate() as ShaderMaterial
	transition_rect.material = shader_material
	set_progress(0.0)


func fade_in() -> void:
	if shader_material == null:
		return

	visible = true
	await tween_progress(0.0, 1.0, fade_in_duration)


func fade_out() -> void:
	if shader_material == null:
		visible = false
		return

	await tween_progress(1.0, 2.0, fade_out_duration)
	visible = false
	set_progress(0.0)


func tween_progress(from: float, to: float, duration: float) -> void:
	if active_tween != null and active_tween.is_running():
		active_tween.kill()

	set_progress(from)
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE)
	active_tween.set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_method(set_progress, from, to, duration)
	await active_tween.finished


func set_progress(value: float) -> void:
	shader_material.set_shader_parameter("progress", value)
