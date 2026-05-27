class_name UiAutoTween extends Node

signal show_started
signal show_finished
signal hide_started
signal hide_finished

enum AnimWhen {
	MANUAL,
	READY,
	VISIBLE,
	TRIGGER,
}

enum AnimType {
	FADE,
	SCALE,
}

enum ScaleFrom {
	CENTER,
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
	CENTER_LEFT,
	CENTER_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT,
}

@export var target: Control
@export var autotween_trigger: UiAutoTween
@export var anim_when: AnimWhen = AnimWhen.MANUAL
@export var start_delay: float = -1.0
@export var anim_type: AnimType = AnimType.FADE
@export var scale_from: ScaleFrom = ScaleFrom.CENTER
@export var duration: float = 0.25
@export var auto_hide_after: float = -1.0
@export var change_visible: bool = true
@export var force_from: bool = false

var tween: Tween
var ignore_visibility_change: bool = false
var base_scale: Vector2
var base_modulate: Color
var has_base_state: bool = false


func _ready() -> void:
	if target == null:
		target = get_parent() as Control

	if target == null:
		push_warning("UiAutoTween: target is not assigned and parent is not a Control.")
		return

	target.set_meta("auto_animate", self)
	cache_base_state()
	prepare_target_for_show()

	if anim_type == AnimType.SCALE:
		set_pivot(scale_from)

	match anim_when:
		AnimWhen.READY:
			await target.ready
			show()
		AnimWhen.VISIBLE:
			target.visibility_changed.connect(on_target_visibility_changed)
		AnimWhen.TRIGGER:
			connect_trigger()


func show() -> void:
	if target == null:
		return

	show_started.emit()
	ignore_visibility_change = true
	cache_base_state()
	set_pivot(scale_from)
	kill_tween()

	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	if start_delay > 0.0:
		tween.tween_interval(start_delay)

	if change_visible:
		tween.tween_property(target, "visible", true, 0.01)
		tween.tween_property(self, "ignore_visibility_change", false, 0.01)
	else:
		ignore_visibility_change = false

	match anim_type:
		AnimType.SCALE:
			tween_show_scale()
		AnimType.FADE:
			tween_show_fade()

	tween.tween_callback(show_finished.emit)
	if auto_hide_after >= 0.0:
		tween.tween_interval(auto_hide_after)
		tween.tween_callback(hide)


func hide() -> void:
	if target == null:
		return

	hide_started.emit()
	ignore_visibility_change = true
	if change_visible and not target.visible:
		target.visible = true
	cache_base_state()
	set_pivot(scale_from)
	kill_tween()

	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	if start_delay > 0.0:
		tween.tween_interval(start_delay)

	match anim_type:
		AnimType.SCALE:
			tween_hide_scale()
		AnimType.FADE:
			tween_hide_fade()

	if change_visible:
		tween.tween_property(target, "visible", false, 0.01)
		tween.tween_property(self, "ignore_visibility_change", false, 0.01)
	else:
		tween.tween_property(self, "ignore_visibility_change", false, 0.01)

	tween.tween_callback(hide_finished.emit)


func prepare_target_for_show() -> void:
	if anim_when == AnimWhen.VISIBLE and target.visible:
		return

	match anim_type:
		AnimType.FADE:
			target.modulate.a = 0.0
		AnimType.SCALE:
			target.scale = Vector2.ZERO


func tween_show_scale() -> void:
	if force_from:
		tween.tween_property(target, "scale", base_scale, duration).from(Vector2.ZERO)
	else:
		tween.tween_property(target, "scale", base_scale, duration)


func tween_hide_scale() -> void:
	if force_from:
		tween.tween_property(target, "scale", Vector2.ZERO, duration).from(base_scale)
	else:
		tween.tween_property(target, "scale", Vector2.ZERO, duration)


func tween_show_fade() -> void:
	if force_from:
		tween.tween_property(target, "modulate:a", base_modulate.a, duration).from(0.0)
	else:
		tween.tween_property(target, "modulate:a", base_modulate.a, duration)


func tween_hide_fade() -> void:
	if force_from:
		tween.tween_property(target, "modulate:a", 0.0, duration).from(base_modulate.a)
	else:
		tween.tween_property(target, "modulate:a", 0.0, duration)


func connect_trigger() -> void:
	if autotween_trigger == null:
		push_warning("UiAutoTween: anim_when is TRIGGER but autotween_trigger is not assigned.")
		return

	autotween_trigger.show_started.connect(show)
	autotween_trigger.hide_started.connect(hide)


func on_target_visibility_changed() -> void:
	if ignore_visibility_change:
		return

	if target.visible:
		show()
	else:
		hide()


func cache_base_state() -> void:
	if has_base_state:
		return

	base_scale = target.scale
	base_modulate = target.modulate
	has_base_state = true


func set_pivot(pivot: ScaleFrom) -> void:
	match pivot:
		ScaleFrom.CENTER:
			target.pivot_offset = target.size / 2.0
		ScaleFrom.TOP_LEFT:
			target.pivot_offset = Vector2.ZERO
		ScaleFrom.TOP_CENTER:
			target.pivot_offset = Vector2(target.size.x / 2.0, 0.0)
		ScaleFrom.TOP_RIGHT:
			target.pivot_offset = Vector2(target.size.x, 0.0)
		ScaleFrom.CENTER_LEFT:
			target.pivot_offset = Vector2(0.0, target.size.y / 2.0)
		ScaleFrom.CENTER_RIGHT:
			target.pivot_offset = Vector2(target.size.x, target.size.y / 2.0)
		ScaleFrom.BOTTOM_LEFT:
			target.pivot_offset = Vector2(0.0, target.size.y)
		ScaleFrom.BOTTOM_CENTER:
			target.pivot_offset = Vector2(target.size.x / 2.0, target.size.y)
		ScaleFrom.BOTTOM_RIGHT:
			target.pivot_offset = target.size


func kill_tween() -> void:
	if tween != null and tween.is_running():
		tween.kill()
