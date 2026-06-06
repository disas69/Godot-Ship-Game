class_name FlagIndicator extends Control

@export var flag_image: TextureRect
@export var show_duration: float = 0.22
@export var hide_duration: float = 0.18
@export var shown_scale := Vector2.ONE
@export var hidden_scale := Vector2(0.35, 0.35)

var is_shown := false
var active_tween: Tween
var target_alpha := 1.0
var target_shown_scale := Vector2.ONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	target_shown_scale = shown_scale
	modulate.a = 0.0
	scale = hidden_scale
	visible = false


func set_flag_texture(texture: Texture2D) -> void:
	if flag_image != null:
		flag_image.texture = texture


func set_marker_transform(screen_position: Vector2, marker_rotation: float) -> void:
	position = screen_position - size * 0.5
	rotation = marker_rotation


func show_indicator(alpha: float = 1.0, scale_multiplier: float = 1.0) -> void:
	alpha = clampf(alpha, 0.0, 1.0)
	var display_scale := shown_scale * maxf(scale_multiplier, 0.0)
	if is_shown:
		set_target_visual(alpha, display_scale)
		return

	is_shown = true
	target_alpha = alpha
	target_shown_scale = display_scale
	visible = true
	play_tween(target_alpha, target_shown_scale, show_duration, Tween.EASE_OUT)


func hide_indicator() -> void:
	if not is_shown:
		return

	is_shown = false
	play_tween(0.0, hidden_scale, hide_duration, Tween.EASE_IN, Callable(self, "hide"))


func set_target_visual(alpha: float, display_scale: Vector2) -> void:
	target_alpha = clampf(alpha, 0.0, 1.0)
	target_shown_scale = display_scale
	if active_tween != null and active_tween.is_valid():
		return
	modulate.a = target_alpha
	scale = target_shown_scale


func play_tween(alpha: float, target_scale: Vector2, duration: float, ease: int, finished_callback: Callable = Callable()) -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_property(self, "modulate:a", alpha, duration).set_trans(Tween.TRANS_QUAD).set_ease(ease)
	active_tween.tween_property(self, "scale", target_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(ease)
	if finished_callback.is_valid():
		active_tween.finished.connect(finished_callback, CONNECT_ONE_SHOT)
	active_tween.finished.connect(clear_active_tween, CONNECT_ONE_SHOT)


func clear_active_tween() -> void:
	active_tween = null
	if is_shown:
		modulate.a = target_alpha
		scale = target_shown_scale
