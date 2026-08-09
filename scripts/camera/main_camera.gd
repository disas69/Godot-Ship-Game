class_name MainCamera extends Node3D

const DYNAMIC_SPLIT_SCREEN_SHADER := preload("res://shaders/dynamic_split_screen.gdshader")

@export var camera: Camera3D
@export var camera_shake: CameraShake
@export var audio_listener: AudioListener3D
@export var targets: Array[Node3D]
@export var smooth_speed: float = 10.0
@export var camera_size: float = 55.0
@export var camera_size_range: Vector2 = Vector2(50, 60)
@export var offset: Vector3 = Vector3.ZERO
@export var min_bounds: Vector3 = Vector3(-10, -10, -10)
@export var max_bounds: Vector3 = Vector3(10, 10, 10)

@export_category("Dynamic Split Screen")
@export var dynamic_split_enabled: bool = true
@export var split_start_distance: float = 55.0
@export var split_blend_distance: float = 18.0
@export var split_camera_max_separation: float = 55.0
@export var split_transition_speed: float = 5.0
@export var split_line_thickness: float = 3.0
@export var split_line_color: Color = Color(0.02, 0.018, 0.014, 1.0)
@export var adaptive_split_line_thickness: bool = true
@export var split_msaa_3d: Viewport.MSAA = Viewport.MSAA_DISABLED
@export var split_render_when_inactive: bool = true

var split_layer: CanvasLayer
var split_view: TextureRect
var split_material: ShaderMaterial
var split_viewport_1: SubViewport
var split_viewport_2: SubViewport
var split_camera_1: Camera3D
var split_camera_2: Camera3D
var split_camera_shake_1: CameraShake
var split_camera_shake_2: CameraShake
var split_amount: float = 0.0

var desired_split_amount: float = 0.0
var target_size: float = 0.0
var current_rig_position := Vector3.ZERO
var split_rig_position_1 := Vector3.ZERO
var split_rig_position_2 := Vector3.ZERO
var _cached_frame: int = -1
var _cached_player_1_uv: Vector2
var _cached_player_2_uv: Vector2



func _ready() -> void:
	add_to_group("MainCamera")

	for i in range(targets.size() - 1, -1, -1):
		var target: Node3D = targets[i]
		if target == null or not target.visible:
			targets.erase(target)
		
	if camera != null:
		camera.size = camera_size

	if audio_listener == null:
		audio_listener = get_node_or_null("AudioListener") as AudioListener3D
	if audio_listener == null and camera != null:
		audio_listener = AudioListener3D.new()
		audio_listener.name = "AudioListener"
		audio_listener.transform = Transform3D(camera.transform.basis, Vector3(0, 60, 65))
		add_child(audio_listener)

	if audio_listener != null:
		audio_listener.make_current()

	target_size = camera_size
	current_rig_position = global_position
	split_rig_position_1 = global_position
	split_rig_position_2 = global_position
	setup_dynamic_split_screen()


func _process(delta: float) -> void:
	prune_targets()

	if targets.size() == 0:
		update_split_visibility()
		return

	var desired_position := get_group_camera_position()
	target_size = get_active_camera_size()
	camera.size = lerp(camera.size, target_size, smooth_speed * delta)
	global_position = global_position.lerp(desired_position, get_lerp_weight(smooth_speed, delta))
	current_rig_position = global_position

	update_dynamic_split_screen(delta, desired_position)


func prune_targets() -> void:
	for i in range(targets.size() - 1, -1, -1):
		if targets[i] == null or not is_instance_valid(targets[i]):
			targets.remove_at(i)


func get_group_camera_position() -> Vector3:
	var desired_position: Vector3 = global_position
	if targets.size() == 1:
		desired_position = targets[0].global_position + offset

	elif targets.size() >= 2:
		var center: Vector3 = Vector3.ZERO	
		for target in targets:
			center += target.global_position
		center /= targets.size()
		desired_position = center + offset

	desired_position.x = clamp(desired_position.x, min_bounds.x, max_bounds.x)
	desired_position.y = clamp(desired_position.y, min_bounds.y, max_bounds.y)
	desired_position.z = clamp(desired_position.z, min_bounds.z, max_bounds.z)
	return desired_position


func get_group_camera_size() -> float:
	if targets.size() <= 1:
		return camera_size

	var center: Vector3 = Vector3.ZERO
	for target in targets:
		center += target.global_position
	center /= targets.size()

	var max_distance: float = 0.0
	for target in targets:
		var distance: float = center.distance_to(target.global_position)
		max_distance = max(max_distance, distance)

	return clamp(max_distance * 2.0, camera_size_range.x, camera_size_range.y)


func get_active_camera_size() -> float:
	if targets.size() <= 1:
		return camera_size
	if dynamic_split_enabled and targets.size() == 2:
		return lerpf(get_group_camera_size(), camera_size, split_amount)
	return get_group_camera_size()


func set_targets(new_targets: Array[Node3D], update_position: bool) -> void:
	targets = new_targets
	if update_position and targets.size() >= 1:
		global_position = targets[0].global_position + offset
		current_rig_position = global_position
		split_rig_position_1 = global_position
		split_rig_position_2 = global_position


func shake(amount: float = 1.0) -> void:
	if camera_shake == null or not is_instance_valid(camera_shake):
		return

	camera_shake.shake(amount)


func shake_for_target(target: Node3D, amount: float = 1.0) -> void:
	if target == null or not is_instance_valid(target):
		shake(amount)
		return

	if is_dynamic_split_active() and targets.size() >= 2:
		if target == targets[0] and split_camera_shake_1 != null:
			split_camera_shake_1.shake(amount)
			return
		elif target == targets[1] and split_camera_shake_2 != null:
			split_camera_shake_2.shake(amount)
			return

	shake(amount)



func get_camera_for_target(target: Variant) -> Camera3D:
	if target == null or not is_instance_valid(target) or not is_dynamic_split_available() or split_amount <= 0.001:
		return camera

	if target == targets[0]:
		return split_camera_1
	if target == targets[1]:
		return split_camera_2
	return camera


func is_dynamic_split_active() -> bool:
	return is_dynamic_split_available() and split_amount > 0.001


func is_screen_point_in_target_region(target: Variant, screen_position: Vector2, screen_size: Vector2) -> bool:
	if target == null or not is_instance_valid(target):
		return true
	if not is_dynamic_split_active():
		return true
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return true
	if not targets.has(target):
		return true

	var target_index := targets.find(target)
	if target_index < 0 or target_index > 1:
		return true

	var current_frame := Engine.get_frames_drawn()
	if _cached_frame != current_frame:
		_cached_frame = current_frame
		_cached_player_1_uv = split_camera_1.unproject_position(targets[0].global_position) / screen_size
		_cached_player_2_uv = split_camera_2.unproject_position(targets[1].global_position) / screen_size

	var point_uv := Vector2(screen_position.x / screen_size.x, screen_position.y / screen_size.y)
	return is_split_uv_owned_by_player_index(point_uv, target_index, _cached_player_1_uv, _cached_player_2_uv)



func is_split_uv_owned_by_player_index(point_uv: Vector2, player_index: int, player_1_uv: Vector2, player_2_uv: Vector2) -> bool:
	var player_delta := player_2_uv - player_1_uv
	var split_slope := 100000.0
	if absf(player_delta.y) > 0.0001:
		split_slope = player_delta.x / player_delta.y

	var split_origin := Vector2(0.5, 0.5)
	var point_line_y := (split_origin.x - point_uv.x) * split_slope + split_origin.y
	var player_1_line_y := (split_origin.x - player_1_uv.x) * split_slope + split_origin.y
	var point_below_line := point_uv.y > point_line_y
	var player_1_below_line := player_1_uv.y > player_1_line_y
	var owner_index := 0 if point_below_line == player_1_below_line else 1
	return owner_index == player_index


func get_split_player_uvs(screen_size: Vector2) -> Array[Vector2]:
	if not is_dynamic_split_active() or targets.size() < 2 or screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return [Vector2(0.5, 0.5), Vector2(0.5, 0.5)]

	var current_frame := Engine.get_frames_drawn()
	if _cached_frame != current_frame:
		_cached_frame = current_frame
		_cached_player_1_uv = split_camera_1.unproject_position(targets[0].global_position) / screen_size
		_cached_player_2_uv = split_camera_2.unproject_position(targets[1].global_position) / screen_size

	return [_cached_player_1_uv, _cached_player_2_uv]


func is_uv_in_player_region(point_uv: Vector2, player_index: int, screen_size: Vector2) -> bool:
	if not is_dynamic_split_active() or targets.size() < 2:
		return true
	if player_index < 0 or player_index > 1:
		return true

	var uvs := get_split_player_uvs(screen_size)
	return is_split_uv_owned_by_player_index(point_uv, player_index, uvs[0], uvs[1])


func setup_dynamic_split_screen() -> void:
	if not dynamic_split_enabled:
		return
	if camera == null:
		return

	split_layer = CanvasLayer.new()
	split_layer.name = "DynamicSplitScreenLayer"
	split_layer.layer = -1
	get_viewport().add_child.call_deferred(split_layer)
	tree_exiting.connect(cleanup_dynamic_split_screen, CONNECT_ONE_SHOT as Object.ConnectFlags)

	split_material = ShaderMaterial.new()
	split_material.shader = DYNAMIC_SPLIT_SCREEN_SHADER

	split_view = TextureRect.new()
	split_view.name = "DynamicSplitScreenView"
	split_view.material = split_material
	split_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	split_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split_view.stretch_mode = TextureRect.STRETCH_SCALE
	split_view.visible = false
	split_layer.add_child(split_view)

	split_viewport_1 = create_split_viewport("DynamicSplitViewport1")
	split_viewport_2 = create_split_viewport("DynamicSplitViewport2")
	add_child(split_viewport_1)
	add_child(split_viewport_2)

	split_camera_1 = create_split_camera("DynamicSplitCamera1")
	split_camera_2 = create_split_camera("DynamicSplitCamera2")
	split_viewport_1.add_child(split_camera_1)
	split_viewport_2.add_child(split_camera_2)

	split_camera_shake_1 = CameraShake.new()
	split_camera_shake_1.name = "CameraShake1"
	split_camera_1.add_child(split_camera_shake_1)

	split_camera_shake_2 = CameraShake.new()
	split_camera_shake_2.name = "CameraShake2"
	split_camera_2.add_child(split_camera_shake_2)


	split_view.texture = split_viewport_1.get_texture()
	split_material.set_shader_parameter("viewport1", split_viewport_1.get_texture())
	split_material.set_shader_parameter("viewport2", split_viewport_2.get_texture())
	get_viewport().size_changed.connect(update_split_viewport_size)
	call_deferred("initialize_split_viewports")


func create_split_viewport(viewport_name: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = viewport_name
	viewport.handle_input_locally = false
	viewport.audio_listener_enable_3d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = split_msaa_3d
	return viewport


func create_split_camera(camera_name: String) -> Camera3D:
	var split_camera := Camera3D.new()
	split_camera.name = camera_name
	split_camera.current = true
	copy_camera_settings(split_camera)
	return split_camera


func initialize_split_viewports() -> void:
	if split_viewport_1 == null or split_viewport_2 == null:
		return

	split_viewport_1.world_3d = get_viewport().world_3d
	split_viewport_2.world_3d = get_viewport().world_3d
	update_split_viewport_size()


func update_dynamic_split_screen(delta: float, group_position: Vector3) -> void:
	if not is_dynamic_split_available():
		split_amount = move_toward(split_amount, 0.0, split_transition_speed * delta)
		update_split_visibility()
		return

	copy_camera_settings(split_camera_1)
	copy_camera_settings(split_camera_2)

	var player_1 := targets[0]
	var player_2 := targets[1]
	var player_delta := player_2.global_position - player_1.global_position
	var player_distance := get_horizontal_length(player_delta)
	var blend_range: float = maxf(split_blend_distance, 0.001)
	desired_split_amount = clampf((player_distance - split_start_distance) / blend_range, 0.0, 1.0)
	split_amount = move_toward(split_amount, desired_split_amount, split_transition_speed * delta)

	if split_amount <= 0.001 and desired_split_amount <= 0.001:
		split_rig_position_1 = global_position
		split_rig_position_2 = global_position
	else:
		var split_target_positions := get_split_rig_targets(player_1, player_2, group_position)
		var lerp_weight := get_lerp_weight(smooth_speed, delta)
		split_rig_position_1 = split_rig_position_1.lerp(split_target_positions[0], lerp_weight)
		split_rig_position_2 = split_rig_position_2.lerp(split_target_positions[1], lerp_weight)

	apply_split_camera_transform(split_camera_1, split_rig_position_1)
	apply_split_camera_transform(split_camera_2, split_rig_position_2)
	update_split_shader_parameters(player_1, player_2, player_distance)
	update_split_visibility()


func get_split_rig_targets(player_1: Node3D, player_2: Node3D, group_position: Vector3) -> Array[Vector3]:
	var player_delta := player_2.global_position - player_1.global_position
	var horizontal_delta := Vector3(player_delta.x, 0.0, player_delta.z)
	var camera_separation: float = split_camera_max_separation
	if camera_separation <= 0.0:
		camera_separation = split_start_distance

	if horizontal_delta.is_zero_approx():
		return [group_position, group_position]

	var clamped_delta := horizontal_delta.normalized() * minf(horizontal_delta.length(), camera_separation)
	var player_1_target := player_1.global_position + clamped_delta * 0.5 + offset
	var player_2_target := player_2.global_position - clamped_delta * 0.5 + offset
	player_1_target.y = group_position.y
	player_2_target.y = group_position.y
	player_1_target = clamp_position(player_1_target)
	player_2_target = clamp_position(player_2_target)

	return [
		group_position.lerp(player_1_target, split_amount),
		group_position.lerp(player_2_target, split_amount),
	]


func update_split_shader_parameters(player_1: Node3D, player_2: Node3D, player_distance: float) -> void:
	if split_material == null:
		return

	var screen_size := get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return

	var player_1_position := split_camera_1.unproject_position(player_1.global_position) / screen_size
	var player_2_position := split_camera_2.unproject_position(player_2.global_position) / screen_size
	var thickness := split_line_thickness
	if adaptive_split_line_thickness:
		thickness = lerpf(0.0, split_line_thickness, clampf((player_distance - split_start_distance) / maxf(split_blend_distance, 0.001), 0.0, 1.0))

	split_material.set_shader_parameter("split_amount", split_amount)
	split_material.set_shader_parameter("player1_position", player_1_position)
	split_material.set_shader_parameter("player2_position", player_2_position)
	split_material.set_shader_parameter("split_line_thickness", thickness)
	split_material.set_shader_parameter("split_line_color", split_line_color)


func update_split_visibility() -> void:
	if split_view == null:
		return

	var should_show := is_dynamic_split_visible()
	split_view.visible = should_show
	if split_viewport_1 != null:
		split_viewport_1.render_target_update_mode = SubViewport.UPDATE_ALWAYS if should_show else SubViewport.UPDATE_DISABLED
	if split_viewport_2 != null:
		split_viewport_2.render_target_update_mode = SubViewport.UPDATE_ALWAYS if should_show else SubViewport.UPDATE_DISABLED


func is_dynamic_split_visible() -> bool:
	return is_dynamic_split_available() and (split_render_when_inactive or split_amount > 0.001)


func is_dynamic_split_available() -> bool:
	return dynamic_split_enabled \
		and split_view != null \
		and split_viewport_1 != null \
		and split_viewport_2 != null \
		and split_camera_1 != null \
		and split_camera_2 != null \
		and targets.size() == 2


func update_split_viewport_size() -> void:
	if split_viewport_1 == null or split_viewport_2 == null:
		return

	var size := get_viewport().get_visible_rect().size
	var viewport_size := Vector2i(maxi(int(size.x), 1), maxi(int(size.y), 1))
	split_viewport_1.size = viewport_size
	split_viewport_2.size = viewport_size
	if split_view != null:
		split_view.position = Vector2.ZERO
		split_view.set_deferred("size", Vector2(viewport_size))
	if split_material != null:
		split_material.set_shader_parameter("viewport_size", Vector2(viewport_size))


func copy_camera_settings(target_camera: Camera3D) -> void:
	if camera == null or target_camera == null:
		return

	target_camera.projection = camera.projection
	target_camera.fov = camera.fov
	target_camera.size = camera.size
	target_camera.near = camera.near
	target_camera.far = camera.far
	target_camera.keep_aspect = camera.keep_aspect
	target_camera.cull_mask = camera.cull_mask
	target_camera.environment = camera.environment
	target_camera.attributes = camera.attributes
	target_camera.h_offset = camera.h_offset
	target_camera.v_offset = camera.v_offset


func apply_split_camera_transform(target_camera: Camera3D, rig_position: Vector3) -> void:
	if target_camera == null or camera == null:
		return

	var rig_transform := Transform3D(global_transform.basis, rig_position)
	target_camera.global_transform = rig_transform * camera.transform


func clamp_position(target_pos: Vector3) -> Vector3:
	var res := target_pos
	res.x = clamp(res.x, min_bounds.x, max_bounds.x)
	res.y = clamp(res.y, min_bounds.y, max_bounds.y)
	res.z = clamp(res.z, min_bounds.z, max_bounds.z)
	return res


func get_horizontal_length(vec: Vector3) -> float:
	return Vector2(vec.x, vec.z).length()


func get_lerp_weight(speed: float, delta: float) -> float:
	return clampf(speed * delta, 0.0, 1.0)


func cleanup_dynamic_split_screen() -> void:
	if split_layer != null and is_instance_valid(split_layer):
		split_layer.queue_free()
