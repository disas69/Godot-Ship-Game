class_name TouchJoystick extends Control

@export var deadzone: float = 0.1
@export var max_radius: float = 65.0
@export var is_aim_joystick: bool = false

@export var base_color: Color = Color(0.06, 0.1, 0.18, 0.5)
@export var border_color: Color = Color(0.8, 0.88, 1.0, 0.5)
@export var knob_color: Color = Color(0.9, 0.95, 1.0, 0.7)
@export var knob_active_color: Color = Color(0.2, 0.75, 1.0, 0.95)

var output_vector: Vector2 = Vector2.ZERO
var touch_index: int = -1
var knob_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and touch_index == -1:
			if is_point_inside(touch.position):
				touch_index = touch.index
				update_knob_position(touch.position)
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == touch_index:
			reset_joystick()
			get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == touch_index:
			update_knob_position(drag.position)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed and touch_index == -1:
				if is_point_inside(mouse.position):
					touch_index = -2
					update_knob_position(mouse.position)
					get_viewport().set_input_as_handled()
			elif not mouse.pressed and touch_index == -2:
				reset_joystick()
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if touch_index == -2:
			update_knob_position(motion.position)
			get_viewport().set_input_as_handled()


func is_point_inside(global_pos: Vector2) -> bool:
	var center: Vector2 = get_global_position() + (size * 0.5)
	return center.distance_to(global_pos) <= max_radius * 1.4


func update_knob_position(global_pos: Vector2) -> void:
	var center: Vector2 = get_global_position() + (size * 0.5)
	var offset: Vector2 = global_pos - center
	knob_position = offset.limit_length(max_radius)

	var raw_vector: Vector2 = knob_position / max_radius
	if raw_vector.length() < deadzone:
		output_vector = Vector2.ZERO
	else:
		output_vector = raw_vector.limit_length(1.0)

	queue_redraw()


func reset_joystick() -> void:
	touch_index = -1
	knob_position = Vector2.ZERO
	output_vector = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5

	# Base circle
	draw_circle(center, max_radius, base_color)
	var ring_col := knob_active_color if touch_index != -1 else border_color
	draw_arc(center, max_radius, 0.0, TAU, 48, ring_col, 3.0, true)

	# Accents
	if is_aim_joystick:
		# Crosshair accent
		var cross_size := 12.0
		draw_line(center - Vector2(cross_size, 0), center + Vector2(cross_size, 0), ring_col * 0.7, 1.5)
		draw_line(center - Vector2(0, cross_size), center + Vector2(0, cross_size), ring_col * 0.7, 1.5)
	else:
		# Direction ticks
		var tick_offset := max_radius - 8.0
		var tick_len := 6.0
		draw_line(center + Vector2(-tick_offset, 0), center + Vector2(-tick_offset + tick_len, 0), ring_col * 0.6, 2.0)
		draw_line(center + Vector2(tick_offset, 0), center + Vector2(tick_offset - tick_len, 0), ring_col * 0.6, 2.0)
		draw_line(center + Vector2(0, -tick_offset), center + Vector2(0, -tick_offset + tick_len), ring_col * 0.6, 2.0)
		draw_line(center + Vector2(0, tick_offset), center + Vector2(0, tick_offset - tick_len), ring_col * 0.6, 2.0)

	# Knob
	var knob_center: Vector2 = center + knob_position
	var knob_r := 28.0
	var cur_knob_color := knob_active_color if touch_index != -1 else knob_color
	draw_circle(knob_center, knob_r, cur_knob_color)
	draw_arc(knob_center, knob_r, 0.0, TAU, 32, Color(1, 1, 1, 0.85), 2.0, true)
