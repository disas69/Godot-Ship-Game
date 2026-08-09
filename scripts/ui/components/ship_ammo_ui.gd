class_name ShipAmmoUI extends Control

@export_category("Layout & Positioning")
## 3D height offset above the ship
@export var height_offset: float = -2.3
## 2D screen offset in pixels relative to ship center (X = left/right, Y = up/down)
@export var screen_offset: Vector2 = Vector2(40.0, -80.0)
## Overall scale multiplier for the ammo circle indicator (e.g. 1.0 = normal, 0.7 = smaller)
@export_range(0.1, 3.0, 0.05) var indicator_scale: float = 0.7
@export var outer_radius: float = 22.0
@export var ring_width: float = 9.0

@export_category("Colors & Half-Transparency")
@export var fill_color: Color = Color(0.2, 0.85, 1.0, 0.65)
@export var bg_color: Color = Color(0.1, 0.12, 0.16, 0.4)
@export var low_ammo_color: Color = Color(1.0, 0.35, 0.2, 0.65)

@export_category("Appearance Animations")
@export var fade_in_duration: float = 0.2
@export var fade_out_duration: float = 0.3

var is_secondary: bool = false
var _secondary_ui: ShipAmmoUI = null
var _target_ship: Node
var _current_ammo: float = 10.0
var _max_ammo: int = 10
var _is_showing: bool = false
var _visibility_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_index = 100
	modulate.a = 0.0
	scale = Vector2(0.4, 0.4)
	visible = false


func setup(ship: Node) -> void:
	_target_ship = ship
	if _target_ship != null:
		if _target_ship.has_signal("ammo_changed"):
			if not _target_ship.is_connected("ammo_changed", on_ship_ammo_changed):
				_target_ship.connect("ammo_changed", on_ship_ammo_changed)
		if "current_ammo" in _target_ship:
			_current_ammo = float(_target_ship.get("current_ammo"))
		if "max_ammo" in _target_ship:
			_max_ammo = int(_target_ship.get("max_ammo"))

	update_visibility_state(true)


func _exit_tree() -> void:
	if _secondary_ui != null and is_instance_valid(_secondary_ui):
		_secondary_ui.queue_free()
		_secondary_ui = null


func on_ship_ammo_changed(current_ammo: float, max_ammo: int) -> void:
	_current_ammo = current_ammo
	_max_ammo = max_ammo
	queue_redraw()
	if _secondary_ui != null and is_instance_valid(_secondary_ui):
		_secondary_ui.on_ship_ammo_changed(current_ammo, max_ammo)


func _process(_delta: float) -> void:
	if is_secondary:
		return

	if _target_ship == null or not is_instance_valid(_target_ship):
		visible = false
		if _secondary_ui != null and is_instance_valid(_secondary_ui):
			_secondary_ui.visible = false
		return

	if "is_destroyed" in _target_ship and _target_ship.get("is_destroyed"):
		visible = false
		if _secondary_ui != null and is_instance_valid(_secondary_ui):
			_secondary_ui.visible = false
		return

	if is_in_menu():
		visible = false
		if _secondary_ui != null and is_instance_valid(_secondary_ui):
			_secondary_ui.visible = false
		return

	var ship_3d := _target_ship as Node3D
	if ship_3d == null:
		visible = false
		if _secondary_ui != null and is_instance_valid(_secondary_ui):
			_secondary_ui.visible = false
		return

	if "current_ammo" in _target_ship:
		_current_ammo = float(_target_ship.get("current_ammo"))
	if "max_ammo" in _target_ship:
		_max_ammo = int(_target_ship.get("max_ammo"))

	if _current_ammo < float(_max_ammo):
		queue_redraw()
		if _secondary_ui != null and is_instance_valid(_secondary_ui):
			_secondary_ui.queue_redraw()

	var world_pos: Vector3 = ship_3d.global_position + Vector3(0, height_offset, 0)
	var screen_size := get_viewport().get_visible_rect().size

	var main_cam := get_tree().get_first_node_in_group("MainCamera") as MainCamera
	var is_split := main_cam != null and is_instance_valid(main_cam) and main_cam.is_dynamic_split_active()

	if not is_split:
		if _secondary_ui != null and is_instance_valid(_secondary_ui):
			_secondary_ui.visible = false

		var camera := get_viewport().get_camera_3d()
		if camera == null or camera.is_position_behind(world_pos):
			visible = false
			return

		var screen_pos := camera.unproject_position(world_pos)
		global_position = screen_pos + screen_offset
		update_visibility_state(false)
		return

	if _secondary_ui == null or not is_instance_valid(_secondary_ui):
		_secondary_ui = ShipAmmoUI.new()
		_secondary_ui.is_secondary = true
		_secondary_ui.name = "ShipAmmoUI_Secondary"
		_target_ship.add_child(_secondary_ui)
		_secondary_ui.setup(_target_ship)

	# Region 0 (Player 1 view)
	var show_0 := false
	var cam0 := main_cam.split_camera_1
	if cam0 != null and not cam0.is_position_behind(world_pos):
		var pos0 := cam0.unproject_position(world_pos)
		var uv0 := Vector2(pos0.x / screen_size.x, pos0.y / screen_size.y)
		if main_cam.is_uv_in_player_region(uv0, 0, screen_size):
			global_position = pos0 + screen_offset
			show_0 = true
	update_visibility_state_custom(self, show_0)

	# Region 1 (Player 2 view)
	var show_1 := false
	var cam1 := main_cam.split_camera_2
	if cam1 != null and not cam1.is_position_behind(world_pos):
		var pos1 := cam1.unproject_position(world_pos)
		var uv1 := Vector2(pos1.x / screen_size.x, pos1.y / screen_size.y)
		if main_cam.is_uv_in_player_region(uv1, 1, screen_size):
			_secondary_ui.global_position = pos1 + screen_offset
			show_1 = true
	update_visibility_state_custom(_secondary_ui, show_1)


func update_visibility_state_custom(target_ui: ShipAmmoUI, in_region: bool) -> void:
	if target_ui == null or not is_instance_valid(target_ui):
		return
	if not in_region:
		target_ui.visible = false
		return

	target_ui.update_visibility_state(false)


func update_visibility_state(instant: bool = false) -> void:
	var is_full := (_current_ammo >= float(_max_ammo) - 0.001)

	if not is_full:
		if not _is_showing:
			_is_showing = true
			visible = true
			if instant:
				modulate.a = 1.0
				scale = Vector2.ONE
			else:
				if _visibility_tween != null and _visibility_tween.is_running():
					_visibility_tween.kill()
				_visibility_tween = create_tween().set_parallel(true)
				_visibility_tween.tween_property(self, "modulate:a", 1.0, fade_in_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				_visibility_tween.tween_property(self, "scale", Vector2.ONE, fade_in_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		if _is_showing:
			_is_showing = false
			if instant:
				modulate.a = 0.0
				scale = Vector2(0.4, 0.4)
				visible = false
			else:
				if _visibility_tween != null and _visibility_tween.is_running():
					_visibility_tween.kill()
				_visibility_tween = create_tween().set_parallel(true)
				_visibility_tween.tween_property(self, "modulate:a", 0.0, fade_out_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				_visibility_tween.tween_property(self, "scale", Vector2(0.4, 0.4), fade_out_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				_visibility_tween.chain().tween_callback(func():
					if not _is_showing:
						visible = false
				)


func is_in_menu() -> bool:
	if _target_ship != null and "ignore_input" in _target_ship and _target_ship.get("ignore_input"):
		return true

	var current_scene := get_tree().current_scene
	if current_scene != null:
		var scene_name := current_scene.name.to_lower()
		var scene_path := current_scene.scene_file_path.to_lower()
		if scene_name == "menu" or scene_path.contains("menu.tscn"):
			return true

	return false


func _draw() -> void:
	if _target_ship == null or _max_ammo <= 0:
		return

	var scaled_outer := outer_radius * indicator_scale
	var scaled_width := ring_width * indicator_scale
	var r_in := scaled_outer - scaled_width
	var r_mid := (scaled_outer + r_in) / 2.0
	var center := Vector2.ZERO

	# Draw background donut ring
	draw_arc(center, r_mid, 0.0, TAU, 32, bg_color, scaled_width, true)

	# Draw foreground ammo fill arc (sweeping counter-clockwise right -> left)
	var t := clampf(_current_ammo / float(_max_ammo), 0.0, 1.0)
	if t > 0.001:
		var start_angle := -PI / 2.0
		var end_angle := start_angle - t * TAU
		var active_color := fill_color if _current_ammo >= 1.0 else low_ammo_color
		draw_arc(center, r_mid, start_angle, end_angle, 32, active_color, scaled_width, true)
