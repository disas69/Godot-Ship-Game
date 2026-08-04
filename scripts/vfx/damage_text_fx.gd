class_name DamageTextFX extends Node3D

signal finished(effect: Node3D)

@export var label: Label3D
@export var hit_messages: Array[String] = ["HIT!", "ATTACKED!", "BAM!", "BLAST!", "DIRECT HIT!"]
@export var destroyed_messages: Array[String] = ["DESTROYED!", "SUNK!", "KILLED!"]
@export var hit_color: Color = Color(1.0, 0.85, 0.2, 1.0)
@export var destroyed_color: Color = Color(1.0, 0.22, 0.2, 1.0)
@export var hit_font_size: int = 48
@export var destroyed_font_size: int = 68
@export var float_distance: float = 2.2
@export var anim_duration: float = 0.75

var tween: Tween
var is_configured: bool = false
var pending_is_destroyed: bool = false
var pending_custom_text: String = ""
var start_pos: Vector3


func _ready() -> void:
	if label == null:
		label = get_node_or_null("Label3D") as Label3D
	if label == null:
		label = Label3D.new()
		label.name = "Label3D"
		add_child(label)

	setup_label_defaults()


func setup_label_defaults() -> void:
	if label == null:
		return

	var font_res := preload("res://fonts/Pixelify_Sans/static/PixelifySans-Bold.ttf")
	if font_res:
		label.font = font_res

	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 18
	label.outline_modulate = Color(0.08, 0.05, 0.04, 1.0)
	label.pixel_size = 0.015
	label.render_priority = 100


func configure(is_destroyed: bool = false, custom_text: String = "") -> void:
	pending_is_destroyed = is_destroyed
	pending_custom_text = custom_text
	is_configured = true


func play() -> void:
	kill_tween()

	if label == null:
		label = get_node_or_null("Label3D") as Label3D

	setup_label_defaults()

	var text_to_show: String = pending_custom_text
	var is_destroyed: bool = pending_is_destroyed

	if text_to_show.is_empty():
		if is_destroyed:
			text_to_show = destroyed_messages.pick_random() if not destroyed_messages.is_empty() else "DESTROYED!"
		else:
			text_to_show = hit_messages.pick_random() if not hit_messages.is_empty() else "HIT!"

	var target_color: Color = destroyed_color if is_destroyed else hit_color
	var font_sz: int = destroyed_font_size if is_destroyed else hit_font_size

	label.text = text_to_show
	label.font_size = font_sz
	label.modulate = Color.WHITE

	rotation_degrees.z = randf_range(-10.0, 10.0)

	var base_scale_multiplier: float = 1.4 if is_destroyed else 1.0
	var final_scale := Vector3.ONE * base_scale_multiplier
	var stretch_scale := Vector3(0.3 * base_scale_multiplier, 1.8 * base_scale_multiplier, base_scale_multiplier)
	var squash_scale := Vector3(1.6 * base_scale_multiplier, 0.5 * base_scale_multiplier, base_scale_multiplier)

	scale = stretch_scale
	start_pos = position

	tween = create_tween().set_parallel(true)

	# Phase 1: Stretch pop to squash with white flash
	tween.tween_property(self, "scale", squash_scale, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", target_color, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Phase 2: Elastic return to target scale
	var bounce_tween := create_tween()
	bounce_tween.tween_interval(0.07)
	bounce_tween.tween_property(self, "scale", final_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Phase 3: Upward floating motion
	var target_pos := start_pos + Vector3.UP * (float_distance * (1.3 if is_destroyed else 1.0))
	tween.tween_property(self, "position", target_pos, anim_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Phase 4: Fade out near end
	var fade_delay: float = anim_duration * 0.55
	var fade_duration: float = anim_duration - fade_delay
	var fade_tween := create_tween()
	fade_tween.tween_interval(fade_delay)
	fade_tween.tween_property(label, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	fade_tween.tween_callback(on_anim_complete)


func on_anim_complete() -> void:
	finished.emit(self)


func reset_for_pool() -> void:
	kill_tween()
	is_configured = false
	pending_is_destroyed = false
	pending_custom_text = ""
	scale = Vector3.ONE
	rotation_degrees = Vector3.ZERO
	if label:
		label.modulate = Color.WHITE
		label.text = ""


func kill_tween() -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	tween = null
