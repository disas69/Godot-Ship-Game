class_name TouchButton extends Control

signal pressed
signal released

@export var radius: float = 42.0
@export var label_text: String = ""

@export var normal_color: Color = Color(0.88, 0.18, 0.18, 0.7)
@export var pressed_color: Color = Color(1.0, 0.35, 0.35, 0.95)
@export var border_color: Color = Color(1.0, 0.88, 0.88, 0.85)

var is_pressed: bool = false
var just_pressed: bool = false
var touch_index: int = -1

var font: Font


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	font = ThemeDB.fallback_font


func consume_just_pressed() -> bool:
	var res := just_pressed
	just_pressed = false
	return res


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and touch_index == -1:
			if is_point_inside(touch.position):
				touch_index = touch.index
				set_pressed_state(true)
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == touch_index:
			touch_index = -1
			set_pressed_state(false)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed and touch_index == -1:
				if is_point_inside(mouse.position):
					touch_index = -2
					set_pressed_state(true)
					get_viewport().set_input_as_handled()
			elif not mouse.pressed and touch_index == -2:
				touch_index = -1
				set_pressed_state(false)
				get_viewport().set_input_as_handled()


func is_point_inside(global_pos: Vector2) -> bool:
	var center: Vector2 = get_global_position() + (size * 0.5)
	return center.distance_to(global_pos) <= radius * 1.3


func set_pressed_state(pressed_val: bool) -> void:
	if is_pressed != pressed_val:
		is_pressed = pressed_val
		if is_pressed:
			just_pressed = true
			pressed.emit()
		else:
			released.emit()
		queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var draw_r: float = radius * (0.92 if is_pressed else 1.0)
	var cur_col := pressed_color if is_pressed else normal_color

	# Simple red disk background & white border
	draw_circle(center, draw_r, cur_col)
	draw_arc(center, draw_r, 0.0, TAU, 36, border_color, 3.0, true)

	if not label_text.is_empty() and font != null:
		var font_size := 14
		var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := center + Vector2(-text_size.x * 0.5, font_size * 0.35)
		draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, 0.9))
