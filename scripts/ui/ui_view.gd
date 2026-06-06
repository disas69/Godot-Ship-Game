class_name UiView extends CanvasLayer

var view_id := ""


func open() -> void:
	visible = true
	if UIManager.should_use_gamepad_focus():
		focus_first_control.call_deferred()


func close() -> void:
	queue_free()


func on_back_requested() -> bool:
	return false


func focus_first_control() -> void:
	if not UIManager.should_use_gamepad_focus():
		return

	var focusables := get_focusable_controls()
	if focusables.is_empty():
		return

	focusables[0].grab_focus()


func refresh_focus() -> void:
	if not UIManager.should_use_gamepad_focus():
		return

	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is Control and is_ancestor_of(focus_owner) and is_focusable_control(focus_owner):
		return

	focus_first_control()


func get_focusable_controls() -> Array[Control]:
	var controls: Array[Control] = []
	collect_focusable_controls(self, controls)
	controls.sort_custom(sort_controls_for_navigation)
	return controls


func collect_focusable_controls(node: Node, controls: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			prepare_focusable_control(control)
			if is_focusable_control(control):
				controls.append(control)

		collect_focusable_controls(child, controls)


func prepare_focusable_control(control: Control) -> void:
	if control is BaseButton or control is OptionButton:
		control.focus_mode = Control.FOCUS_ALL


func is_focusable_control(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	if control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false

	return true


func sort_controls_for_navigation(a: Control, b: Control) -> bool:
	var a_position := a.global_position
	var b_position := b.global_position
	if not is_equal_approx(a_position.y, b_position.y):
		return a_position.y < b_position.y

	return a_position.x < b_position.x
