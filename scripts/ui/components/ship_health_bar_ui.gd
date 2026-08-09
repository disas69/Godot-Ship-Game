class_name ShipHealthBarUI extends Control

@export_category("Graphics Overrides")
@export var filled_shield_texture: Texture2D
@export var empty_shield_texture: Texture2D

@export_category("Layout & Positioning")
@export var height_offset: float = -2.3
@export var circle_size: Vector2 = Vector2(14, 14)
@export var circle_spacing: float = 3.0

@export_category("Colors & Effects")
@export var filled_alpha: float = 0.85
@export var empty_alpha: float = 0.5
@export var flash_modulate: Color = Color(3.5, 3.5, 3.5, 1.0)

var is_secondary: bool = false
var _secondary_ui: ShipHealthBarUI = null
var _target_ship: Node
var _container: HBoxContainer
var _slots: Array[TextureRect] = []
var _current_hp: int = -1
var _max_hp: int = -1
var _active_tweens: Dictionary = {}

static var _cached_filled_texture: ImageTexture
static var _cached_empty_texture: ImageTexture


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_index = 100
	_ensure_container()
	_ensure_textures()


func setup(ship: Node) -> void:
	_target_ship = ship
	if _target_ship != null and _target_ship.has_signal("health_changed"):
		if not _target_ship.is_connected("health_changed", on_ship_health_changed):
			_target_ship.connect("health_changed", on_ship_health_changed)


func _exit_tree() -> void:
	if _secondary_ui != null and is_instance_valid(_secondary_ui):
		_secondary_ui.queue_free()
		_secondary_ui = null


func _ensure_container() -> void:
	if _container == null:
		_container = HBoxContainer.new()
		_container.name = "SlotsContainer"
		_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_container.alignment = BoxContainer.ALIGNMENT_CENTER
		_container.add_theme_constant_override("separation", int(circle_spacing))
		add_child(_container)


func _ensure_textures() -> void:
	if filled_shield_texture == null:
		if _cached_filled_texture == null:
			_cached_filled_texture = _generate_circle_texture(true)
		filled_shield_texture = _cached_filled_texture

	if empty_shield_texture == null:
		if _cached_empty_texture == null:
			_cached_empty_texture = _generate_circle_texture(false)
		empty_shield_texture = _cached_empty_texture


static func _generate_circle_texture(is_filled: bool) -> ImageTexture:
	var tex_size := 128
	var center := float(tex_size) / 2.0
	var radius := 54.0
	var border_width := 8.0
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)

	var color_fill := Color(0.22, 0.88, 0.36, 1.0) if is_filled else Color(0.12, 0.13, 0.16, 0.75)
	var color_border := Color(0.08, 0.45, 0.15, 1.0) if is_filled else Color(0.5, 0.52, 0.58, 0.85)
	var color_highlight := Color(0.48, 0.96, 0.58, 1.0) if is_filled else Color(0.22, 0.23, 0.28, 0.6)

	for y in range(tex_size):
		for x in range(tex_size):
			var dx := float(x) - center + 0.5
			var dy := float(y) - center + 0.5
			var dist := sqrt(dx * dx + dy * dy)

			if dist > radius + 1.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var alpha := 1.0
			if dist > radius - 1.5:
				alpha = clampf((radius + 1.5 - dist) / 3.0, 0.0, 1.0)

			var px_color: Color
			if dist >= radius - border_width:
				px_color = color_border
			else:
				var factor := (dy + radius) / (radius * 2.0)
				px_color = color_fill.lerp(color_highlight, (1.0 - factor) * 0.4)

			px_color.a *= alpha
			img.set_pixel(x, y, px_color)

	return ImageTexture.create_from_image(img)


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

	var world_pos: Vector3 = ship_3d.global_position + Vector3(0, height_offset, 0)
	var screen_size := get_viewport().get_visible_rect().size
	var container_size := _container.get_combined_minimum_size() if _container != null else circle_size
	if container_size == Vector2.ZERO:
		container_size = Vector2(_max_hp * (circle_size.x + circle_spacing), circle_size.y)

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
		global_position = screen_pos - container_size / 2.0
		visible = true
		return

	if _secondary_ui == null or not is_instance_valid(_secondary_ui):
		_secondary_ui = ShipHealthBarUI.new()
		_secondary_ui.is_secondary = true
		_secondary_ui.name = "ShipHealthBarUI_Secondary"
		_target_ship.add_child(_secondary_ui)
		_secondary_ui.setup(_target_ship)
		_secondary_ui.update_health(_current_hp, _max_hp, false)

	var show_0 := false
	var cam0 := main_cam.split_camera_1
	if cam0 != null and not cam0.is_position_behind(world_pos):
		var pos0 := cam0.unproject_position(world_pos)
		var uv0 := Vector2(pos0.x / screen_size.x, pos0.y / screen_size.y)
		if main_cam.is_uv_in_player_region(uv0, 0, screen_size):
			global_position = pos0 - container_size / 2.0
			show_0 = true
	visible = show_0

	var show_1 := false
	var cam1 := main_cam.split_camera_2
	if cam1 != null and not cam1.is_position_behind(world_pos):
		var pos1 := cam1.unproject_position(world_pos)
		var uv1 := Vector2(pos1.x / screen_size.x, pos1.y / screen_size.y)
		if main_cam.is_uv_in_player_region(uv1, 1, screen_size):
			_secondary_ui.global_position = pos1 - container_size / 2.0
			show_1 = true
	_secondary_ui.visible = show_1


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


func update_health(current_hp: int, max_hp: int, animate_hit: bool = true) -> void:
	_ensure_container()
	_ensure_textures()
	var previous_hp := _current_hp
	_current_hp = current_hp
	_max_hp = max_hp

	_rebuild_slots_if_needed(max_hp)

	for i in range(max_hp):
		var slot := _slots[i]
		var is_active := (i < current_hp)

		if previous_hp >= 0 and animate_hit and i == current_hp and i < previous_hp:
			_animate_hit_slot(slot, i)
		else:
			_set_slot_state(slot, is_active)

	if _secondary_ui != null and is_instance_valid(_secondary_ui):
		_secondary_ui.update_health(current_hp, max_hp, animate_hit)


func _rebuild_slots_if_needed(max_hp: int) -> void:
	if _slots.size() == max_hp:
		return

	for slot in _slots:
		if is_instance_valid(slot):
			slot.queue_free()
	_slots.clear()

	for i in range(max_hp):
		var slot := TextureRect.new()
		slot.name = "Slot_%d" % i
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.custom_minimum_size = circle_size
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.pivot_offset = circle_size / 2.0
		slot.texture = filled_shield_texture
		_container.add_child(slot)
		_slots.append(slot)


func _set_slot_state(slot: TextureRect, is_active: bool) -> void:
	if slot == null or not is_instance_valid(slot):
		return

	_kill_slot_tween(slot)
	slot.texture = filled_shield_texture if is_active else empty_shield_texture
	slot.scale = Vector2.ONE
	slot.modulate = Color(1.0, 1.0, 1.0, filled_alpha if is_active else empty_alpha)


func _animate_hit_slot(slot: TextureRect, slot_index: int) -> void:
	if slot == null or not is_instance_valid(slot):
		return

	_kill_slot_tween(slot)

	var tween := create_tween()
	_active_tweens[slot_index] = tween

	slot.pivot_offset = slot.size / 2.0
	slot.texture = filled_shield_texture
	slot.modulate = flash_modulate
	var punch_scale := Vector2(1.55, 1.55)

	tween.tween_property(slot, "scale", punch_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_callback(func():
		if is_instance_valid(slot):
			slot.texture = empty_shield_texture
	)

	tween.parallel().tween_property(slot, "modulate", Color(1.0, 1.0, 1.0, empty_alpha), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slot, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _kill_slot_tween(slot: TextureRect) -> void:
	var slot_index := _slots.find(slot)
	if slot_index >= 0 and _active_tweens.has(slot_index):
		var existing_tween := _active_tweens[slot_index] as Tween
		if existing_tween != null and existing_tween.is_running():
			existing_tween.kill()
		_active_tweens.erase(slot_index)


func on_ship_health_changed(current_hp: int, max_hp: int) -> void:
	update_health(current_hp, max_hp, true)


func fade_out_and_destroy(duration: float = 0.4) -> void:
	if _secondary_ui != null and is_instance_valid(_secondary_ui):
		_secondary_ui.fade_out_and_destroy(duration)
		_secondary_ui = null
	var tween := create_tween().set_parallel(true)
	for slot in _slots:
		if is_instance_valid(slot):
			tween.tween_property(slot, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(queue_free)
