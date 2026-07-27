class_name UiTweenContainer extends Control

enum AnimWhen {
	MANUAL,
	READY,
}

enum AnimType {
	SCALE,
	SLIDE_IN_LEFT,
	SLIDE_IN_RIGHT,
}

enum OrderType {
	START_TOP,
	START_BOTTOM,
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
@export var anim_when: AnimWhen = AnimWhen.READY
@export var anim_type: AnimType = AnimType.SLIDE_IN_LEFT
@export var order_type: OrderType = OrderType.START_TOP
@export var scale_from: ScaleFrom = ScaleFrom.CENTER
@export var duration: float = 0.2
@export var delay_appear: float = 0.0
@export var delay_between_elements: float = 0.075
@export var change_visible: bool = false

var tween: Tween
var base_positions: Dictionary[int, Vector2] = {}
var base_scales: Dictionary[int, Vector2] = {}
var base_modulates: Dictionary[int, Color] = {}


func _ready() -> void:
	if target == null:
		target = self

	target.set_meta("container_tween", self)
	prepare_children_for_appear()

	if anim_when == AnimWhen.READY:
		appear.call_deferred()


func appear() -> void:
	animate(true)


func disappear() -> void:
	animate(false)


func prepare_children_for_appear() -> void:
	for child in get_control_children():
		cache_base_state(child)
		if anim_type == AnimType.SCALE:
			child.scale = Vector2.ZERO
			child.modulate.a = 0.0
			set_pivot(child, scale_from)
		else:
			child.modulate.a = 0.0

		if change_visible:
			child.visible = false


func animate(appearing: bool) -> void:
	if target == null:
		push_warning("UiTweenContainer: target is not assigned.")
		return

	var children := get_control_children()
	if children.is_empty():
		return

	for child in children:
		cache_base_state(child)
		set_pivot(child, scale_from)
		if appearing:
			prepare_child_for_appear(child)
		if appearing and change_visible:
			child.visible = true

	kill_tween()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)

	if appearing and delay_appear > 0.0:
		tween.tween_interval(delay_appear)
		tween.chain().tween_interval(0.01)

	if order_type == OrderType.START_BOTTOM:
		children.reverse()

	var index := 0
	for child in children:
		var delay := delay_between_elements * index
		animate_child(child, appearing, delay)
		index += 1

	if not appearing and change_visible:
		tween.finished.connect(hide_children)


func animate_child(child: Control, appearing: bool, delay: float) -> void:
	match anim_type:
		AnimType.SCALE:
			animate_child_scale(child, appearing, delay)
		AnimType.SLIDE_IN_LEFT:
			animate_child_slide(child, appearing, delay, -1.0)
		AnimType.SLIDE_IN_RIGHT:
			animate_child_slide(child, appearing, delay, 1.0)


func prepare_child_for_appear(child: Control) -> void:
	match anim_type:
		AnimType.SCALE:
			child.scale = Vector2.ZERO
			child.modulate.a = 0.0
		AnimType.SLIDE_IN_LEFT, AnimType.SLIDE_IN_RIGHT:
			child.modulate.a = 0.0


func animate_child_scale(child: Control, appearing: bool, delay: float) -> void:
	var from_scale := Vector2.ZERO
	var to_scale := get_base_scale(child)
	var from_alpha := 0.0
	var to_alpha := get_base_modulate(child).a

	if not appearing:
		from_scale = get_base_scale(child)
		to_scale = Vector2.ZERO
		from_alpha = get_base_modulate(child).a
		to_alpha = 0.0

	tween.tween_property(child, "scale", to_scale, duration).from(from_scale).set_delay(delay)
	tween.tween_property(child, "modulate:a", to_alpha, 0.01).from(from_alpha).set_delay(delay)


func animate_child_slide(child: Control, appearing: bool, delay: float, direction: float) -> void:
	var base_position := get_base_position(child)
	var offset := Vector2(child.size.x * direction, 0.0)
	var from_position := base_position - offset
	var to_position := base_position
	var from_alpha := 0.0
	var to_alpha := get_base_modulate(child).a

	if not appearing:
		from_position = base_position
		to_position = base_position - offset
		from_alpha = get_base_modulate(child).a
		to_alpha = 0.0

	tween.tween_property(child, "position", to_position, duration).from(from_position).set_delay(delay)
	tween.tween_property(child, "modulate:a", to_alpha, 0.05).from(from_alpha).set_delay(delay)


func hide_children() -> void:
	for child in get_control_children():
		child.visible = false


func cache_base_state(child: Control) -> void:
	var instance_id := child.get_instance_id()
	if not base_positions.has(instance_id):
		base_positions[instance_id] = child.position
	if not base_scales.has(instance_id):
		if not is_zero_approx(child.scale.x) and not is_zero_approx(child.scale.y):
			base_scales[instance_id] = child.scale
	if not base_modulates.has(instance_id):
		if child.modulate.a > 0.0:
			base_modulates[instance_id] = child.modulate


func get_base_position(child: Control) -> Vector2:
	var instance_id := child.get_instance_id()
	if base_positions.has(instance_id):
		return base_positions[instance_id]
	return child.position


func get_base_scale(child: Control) -> Vector2:
	var instance_id := child.get_instance_id()
	if base_scales.has(instance_id):
		var s: Vector2 = base_scales[instance_id]
		if not is_zero_approx(s.x) and not is_zero_approx(s.y):
			return s
	if not is_zero_approx(child.scale.x) and not is_zero_approx(child.scale.y):
		return child.scale
	return Vector2.ONE


func get_base_modulate(child: Control) -> Color:
	var instance_id := child.get_instance_id()
	if base_modulates.has(instance_id):
		var c: Color = base_modulates[instance_id]
		if c.a > 0.0:
			return c
	var col := child.modulate
	if col.a == 0.0:
		col.a = 1.0
	return col


func set_pivot(control: Control, pivot: ScaleFrom) -> void:
	match pivot:
		ScaleFrom.CENTER:
			control.pivot_offset = control.size / 2.0
		ScaleFrom.TOP_LEFT:
			control.pivot_offset = Vector2.ZERO
		ScaleFrom.TOP_CENTER:
			control.pivot_offset = Vector2(control.size.x / 2.0, 0.0)
		ScaleFrom.TOP_RIGHT:
			control.pivot_offset = Vector2(control.size.x, 0.0)
		ScaleFrom.CENTER_LEFT:
			control.pivot_offset = Vector2(0.0, control.size.y / 2.0)
		ScaleFrom.CENTER_RIGHT:
			control.pivot_offset = Vector2(control.size.x, control.size.y / 2.0)
		ScaleFrom.BOTTOM_LEFT:
			control.pivot_offset = Vector2(0.0, control.size.y)
		ScaleFrom.BOTTOM_CENTER:
			control.pivot_offset = Vector2(control.size.x / 2.0, control.size.y)
		ScaleFrom.BOTTOM_RIGHT:
			control.pivot_offset = control.size


func get_control_children() -> Array[Control]:
	var controls: Array[Control] = []
	if target == null:
		return controls

	for child in target.get_children():
		if child is Control:
			controls.append(child)

	return controls


func kill_tween() -> void:
	if tween != null and tween.is_running():
		tween.kill()
