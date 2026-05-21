@tool
extends EditorPlugin

const OVERLAY_SCENE := preload("res://addons/ui_layout_controls/UILayoutControlsOverlay.tscn")
const EPSILON := 0.0001
const CONTROL_LAYOUT_MODE_ANCHORED := 1

const LAYOUT_PROPERTIES := [
	"layout_mode",
	"anchor_left",
	"anchor_top",
	"anchor_right",
	"anchor_bottom",
	"offset_left",
	"offset_top",
	"offset_right",
	"offset_bottom",
	"pivot_offset",
]

const ANCHOR_PRESETS := [
	{"name": "Top Left", "anchors": Vector4(0.0, 0.0, 0.0, 0.0), "pivot": Vector2(0.0, 0.0)},
	{"name": "Top Center", "anchors": Vector4(0.5, 0.0, 0.5, 0.0), "pivot": Vector2(0.5, 0.0)},
	{"name": "Top Right", "anchors": Vector4(1.0, 0.0, 1.0, 0.0), "pivot": Vector2(1.0, 0.0)},
	{"name": "Middle Left", "anchors": Vector4(0.0, 0.5, 0.0, 0.5), "pivot": Vector2(0.0, 0.5)},
	{"name": "Center", "anchors": Vector4(0.5, 0.5, 0.5, 0.5), "pivot": Vector2(0.5, 0.5)},
	{"name": "Middle Right", "anchors": Vector4(1.0, 0.5, 1.0, 0.5), "pivot": Vector2(1.0, 0.5)},
	{"name": "Bottom Left", "anchors": Vector4(0.0, 1.0, 0.0, 1.0), "pivot": Vector2(0.0, 1.0)},
	{"name": "Bottom Center", "anchors": Vector4(0.5, 1.0, 0.5, 1.0), "pivot": Vector2(0.5, 1.0)},
	{"name": "Bottom Right", "anchors": Vector4(1.0, 1.0, 1.0, 1.0), "pivot": Vector2(1.0, 1.0)},
	{"name": "Stretch Full", "anchors": Vector4(0.0, 0.0, 1.0, 1.0), "pivot": Vector2(0.5, 0.5)},
	{"name": "Stretch Horizontal Top", "anchors": Vector4(0.0, 0.0, 1.0, 0.0), "pivot": Vector2(0.5, 0.0)},
	{"name": "Stretch Horizontal Middle", "anchors": Vector4(0.0, 0.5, 1.0, 0.5), "pivot": Vector2(0.5, 0.5)},
	{"name": "Stretch Horizontal Bottom", "anchors": Vector4(0.0, 1.0, 1.0, 1.0), "pivot": Vector2(0.5, 1.0)},
	{"name": "Stretch Vertical Left", "anchors": Vector4(0.0, 0.0, 0.0, 1.0), "pivot": Vector2(0.0, 0.5)},
	{"name": "Stretch Vertical Center", "anchors": Vector4(0.5, 0.0, 0.5, 1.0), "pivot": Vector2(0.5, 0.5)},
	{"name": "Stretch Vertical Right", "anchors": Vector4(1.0, 0.0, 1.0, 1.0), "pivot": Vector2(1.0, 0.5)},
]

var overlay: Control
var selected_control: Control
var is_refreshing := false

var node_name_label: Label
var container_warning: Label
var anchor_preset: OptionButton
var anchored_x: SpinBox
var anchored_y: SpinBox
var width: SpinBox
var height: SpinBox
var pivot_x: SpinBox
var pivot_y: SpinBox


func _enter_tree() -> void:
	overlay = OVERLAY_SCENE.instantiate()
	overlay.visible = false
	get_editor_interface().get_editor_main_screen().add_child(overlay)

	_bind_overlay()
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)
	_on_selection_changed()


func _exit_tree() -> void:
	var selection := get_editor_interface().get_selection()
	if selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.disconnect(_on_selection_changed)

	if overlay:
		overlay.queue_free()
	overlay = null
	selected_control = null


func _bind_overlay() -> void:
	node_name_label = overlay.get_node("%NodeNameLabel")
	container_warning = overlay.get_node("%ContainerWarning")
	anchor_preset = overlay.get_node("%AnchorPreset")
	anchored_x = overlay.get_node("%AnchoredX")
	anchored_y = overlay.get_node("%AnchoredY")
	width = overlay.get_node("%Width")
	height = overlay.get_node("%Height")
	pivot_x = overlay.get_node("%PivotX")
	pivot_y = overlay.get_node("%PivotY")

	anchor_preset.clear()
	anchor_preset.add_item("Custom", 0)
	for preset_index in ANCHOR_PRESETS.size():
		anchor_preset.add_item(ANCHOR_PRESETS[preset_index]["name"], preset_index + 1)

	anchor_preset.item_selected.connect(_on_anchor_preset_selected)

	for spin_box: SpinBox in [anchored_x, anchored_y, width, height, pivot_x, pivot_y]:
		spin_box.value_changed.connect(_on_layout_value_changed)


func _on_selection_changed() -> void:
	var selection := get_editor_interface().get_selection().get_selected_nodes()
	if selection.size() == 1 and selection[0] is Control:
		selected_control = selection[0]
		overlay.visible = true
		_refresh_fields()
	else:
		selected_control = null
		if overlay:
			overlay.visible = false


func _refresh_fields_deferred() -> void:
	call_deferred("_refresh_fields")


func _refresh_fields() -> void:
	if is_refreshing:
		return
	if not _has_valid_selection():
		return

	is_refreshing = true

	node_name_label.text = selected_control.name
	container_warning.visible = selected_control.get_parent() is Container

	var anchored_position := _get_anchored_position(selected_control)
	var pivot_ratio := _get_pivot_ratio(selected_control, selected_control.size)

	anchored_x.set_value_no_signal(anchored_position.x)
	anchored_y.set_value_no_signal(anchored_position.y)
	width.set_value_no_signal(selected_control.size.x)
	height.set_value_no_signal(selected_control.size.y)
	pivot_x.set_value_no_signal(pivot_ratio.x)
	pivot_y.set_value_no_signal(pivot_ratio.y)
	anchor_preset.select(_get_matching_anchor_preset(selected_control))

	is_refreshing = false


func _on_layout_value_changed(_value: float) -> void:
	if is_refreshing or not _has_valid_selection():
		return

	var anchors := _get_anchor_rect(selected_control)
	var anchored_position := Vector2(anchored_x.value, anchored_y.value)
	var rect_size := Vector2(maxf(width.value, 0.0), maxf(height.value, 0.0))
	var pivot_ratio := Vector2(clampf(pivot_x.value, 0.0, 1.0), clampf(pivot_y.value, 0.0, 1.0))

	_apply_anchored_layout(
		selected_control,
		anchors,
		anchored_position,
		rect_size,
		pivot_ratio,
		"Edit Control Anchored Layout"
	)


func _on_anchor_preset_selected(index: int) -> void:
	if is_refreshing or index <= 0 or not _has_valid_selection():
		return

	var preset: Dictionary = ANCHOR_PRESETS[index - 1]
	_apply_visual_rect_layout(
		selected_control,
		preset["anchors"],
		selected_control.position,
		selected_control.size,
		preset["pivot"],
		"Set Control Anchor Preset"
	)


func _has_valid_selection() -> bool:
	return selected_control != null and is_instance_valid(selected_control)


func _get_anchored_position(control: Control) -> Vector2:
	var parent_size := _get_parent_size(control)
	var pivot_ratio := _get_pivot_ratio(control, control.size)
	var anchor_reference := _get_anchor_reference(_get_anchor_rect(control), parent_size, pivot_ratio)
	return control.position + control.pivot_offset - anchor_reference


func _get_parent_size(control: Control) -> Vector2:
	var parent := control.get_parent()
	if parent is Control:
		return (parent as Control).size

	var viewport := control.get_viewport()
	if viewport:
		return viewport.get_visible_rect().size

	return Vector2.ZERO


func _get_pivot_ratio(control: Control, rect_size: Vector2) -> Vector2:
	return Vector2(
		_safe_ratio(control.pivot_offset.x, rect_size.x),
		_safe_ratio(control.pivot_offset.y, rect_size.y)
	)


func _safe_ratio(value: float, size_value: float) -> float:
	if absf(size_value) <= EPSILON:
		return 0.0
	return clampf(value / size_value, 0.0, 1.0)


func _get_anchor_rect(control: Control) -> Vector4:
	return Vector4(control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom)


func _get_anchor_reference(anchors: Vector4, parent_size: Vector2, pivot_ratio: Vector2) -> Vector2:
	return Vector2(
		lerpf(anchors.x, anchors.z, pivot_ratio.x) * parent_size.x,
		lerpf(anchors.y, anchors.w, pivot_ratio.y) * parent_size.y
	)


func _apply_anchored_layout(
	control: Control,
	anchors: Vector4,
	anchored_position: Vector2,
	rect_size: Vector2,
	pivot_ratio: Vector2,
	action_name: String
) -> void:
	var parent_size := _get_parent_size(control)
	var pivot_offset := rect_size * pivot_ratio
	var anchor_reference := _get_anchor_reference(anchors, parent_size, pivot_ratio)
	var top_left := anchor_reference + anchored_position - pivot_offset
	var values := _make_native_layout_values(anchors, parent_size, top_left, rect_size, pivot_offset, control.layout_mode)
	_commit_layout(control, values, action_name)


func _apply_visual_rect_layout(
	control: Control,
	anchors: Vector4,
	top_left: Vector2,
	rect_size: Vector2,
	pivot_ratio: Vector2,
	action_name: String
) -> void:
	var parent_size := _get_parent_size(control)
	var pivot_offset := rect_size * pivot_ratio
	var values := _make_native_layout_values(anchors, parent_size, top_left, rect_size, pivot_offset, CONTROL_LAYOUT_MODE_ANCHORED)
	_commit_layout(control, values, action_name)


func _make_native_layout_values(
	anchors: Vector4,
	parent_size: Vector2,
	top_left: Vector2,
	rect_size: Vector2,
	pivot_offset: Vector2,
	layout_mode: int
) -> Dictionary:
	return {
		"layout_mode": layout_mode,
		"anchor_left": anchors.x,
		"anchor_top": anchors.y,
		"anchor_right": anchors.z,
		"anchor_bottom": anchors.w,
		"offset_left": top_left.x - anchors.x * parent_size.x,
		"offset_top": top_left.y - anchors.y * parent_size.y,
		"offset_right": top_left.x + rect_size.x - anchors.z * parent_size.x,
		"offset_bottom": top_left.y + rect_size.y - anchors.w * parent_size.y,
		"pivot_offset": pivot_offset,
	}


func _capture_layout(control: Control) -> Dictionary:
	return {
		"layout_mode": control.layout_mode,
		"anchor_left": control.anchor_left,
		"anchor_top": control.anchor_top,
		"anchor_right": control.anchor_right,
		"anchor_bottom": control.anchor_bottom,
		"offset_left": control.offset_left,
		"offset_top": control.offset_top,
		"offset_right": control.offset_right,
		"offset_bottom": control.offset_bottom,
		"pivot_offset": control.pivot_offset,
	}


func _commit_layout(control: Control, values: Dictionary, action_name: String) -> void:
	var before := _capture_layout(control)
	if _layout_values_equal(before, values):
		_refresh_fields()
		return

	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	for property_name: String in LAYOUT_PROPERTIES:
		undo_redo.add_do_property(control, property_name, values[property_name])
		undo_redo.add_undo_property(control, property_name, before[property_name])
	undo_redo.add_do_method(self, "_refresh_fields_deferred")
	undo_redo.add_undo_method(self, "_refresh_fields_deferred")
	undo_redo.commit_action()

	_refresh_fields()


func _layout_values_equal(a: Dictionary, b: Dictionary) -> bool:
	for property_name: String in LAYOUT_PROPERTIES:
		var left = a[property_name]
		var right = b[property_name]
		if left is Vector2 and right is Vector2:
			if not left.is_equal_approx(right):
				return false
		elif absf(float(left) - float(right)) > EPSILON:
			return false
	return true


func _get_matching_anchor_preset(control: Control) -> int:
	var anchors := _get_anchor_rect(control)
	var pivot_ratio := _get_pivot_ratio(control, control.size)
	for preset_index in ANCHOR_PRESETS.size():
		var preset: Dictionary = ANCHOR_PRESETS[preset_index]
		if anchors.is_equal_approx(preset["anchors"]) and pivot_ratio.is_equal_approx(preset["pivot"]):
			return preset_index + 1
	return 0
