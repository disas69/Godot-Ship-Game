class_name FishFlock
extends Node3D

@export_group("Custom Assets")
@export var custom_fish_scene: PackedScene = null
@export var custom_fish_mesh: Mesh = null
@export var custom_fish_texture: Texture2D = null

@export_group("Flock Settings")
@export var fish_count: int = 18
@export var roaming_radius: float = 12.0
@export var swim_speed: float = 3.5
@export var max_speed: float = 6.0
@export var fish_scale: Vector3 = Vector3(1.3, 1.3, 1.3)
## Pure dark shadow color for distinct underwater silhouette visibility
@export var fish_color: Color = Color(0.02, 0.03, 0.04, 1.0)
## Max vertical deviation above/below node position
@export var vertical_range: float = 0.4

@export_group("Boid Behavior Parameters")
@export var neighbor_distance: float = 5.0
@export var separation_distance: float = 1.8
@export var weight_cohesion: float = 1.0
@export var weight_separation: float = 1.6
@export var weight_alignment: float = 1.0
@export var weight_bounds: float = 2.0

var _multimesh_instance: MultiMeshInstance3D = null
var _visibility_notifier: VisibleOnScreenNotifier3D = null

# Per-fish schooling parameters
var _rad_x: PackedFloat32Array = PackedFloat32Array()
var _rad_z: PackedFloat32Array = PackedFloat32Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _orbit_speed: PackedFloat32Array = PackedFloat32Array()

var _px: PackedFloat32Array = PackedFloat32Array()
var _py: PackedFloat32Array = PackedFloat32Array()
var _pz: PackedFloat32Array = PackedFloat32Array()

var _dir_x: PackedFloat32Array = PackedFloat32Array()
var _dir_y: PackedFloat32Array = PackedFloat32Array()
var _dir_z: PackedFloat32Array = PackedFloat32Array()

var _scl_x: PackedFloat32Array = PackedFloat32Array()
var _scl_y: PackedFloat32Array = PackedFloat32Array()
var _scl_z: PackedFloat32Array = PackedFloat32Array()

var _center_x: float = 0.0
var _center_z: float = 0.0
var target_roam_point: Vector3 = Vector3.ZERO
var roam_change_timer: float = 0.0
var _time_passed: float = 0.0

static var primitive_fish_mesh_cache: ArrayMesh = null

func _ready() -> void:
	target_roam_point = global_position
	_center_x = 0.0
	_center_z = 0.0
	spawn_fish_flock()

func spawn_fish_flock() -> void:
	if _multimesh_instance != null and is_instance_valid(_multimesh_instance):
		_multimesh_instance.queue_free()
	if _visibility_notifier != null and is_instance_valid(_visibility_notifier):
		_visibility_notifier.queue_free()

	_rad_x.clear(); _rad_z.clear(); _phase.clear(); _orbit_speed.clear()
	_px.clear(); _py.clear(); _pz.clear()
	_dir_x.clear(); _dir_y.clear(); _dir_z.clear()
	_scl_x.clear(); _scl_y.clear(); _scl_z.clear()

	var fish_mesh: Mesh = custom_fish_mesh
	if fish_mesh == null and custom_fish_scene != null:
		var temp_inst = custom_fish_scene.instantiate()
		if temp_inst is MeshInstance3D:
			fish_mesh = temp_inst.mesh
		else:
			var mi = temp_inst.find_child("*", true, false) as MeshInstance3D
			if mi != null:
				fish_mesh = mi.mesh
		temp_inst.free()

	if fish_mesh == null:
		fish_mesh = get_or_create_primitive_fish_mesh()

	_multimesh_instance = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = fish_mesh
	mm.instance_count = fish_count
	_multimesh_instance.multimesh = mm

	var fish_shader = preload("res://shaders/fish_wiggle.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = fish_shader
	mat.set_shader_parameter("albedo_color", fish_color)
	mat.set_shader_parameter("swim_speed", 8.0)
	mat.set_shader_parameter("wiggle_amplitude", 0.25)
	if custom_fish_texture != null:
		mat.set_shader_parameter("albedo_texture", custom_fish_texture)
		mat.set_shader_parameter("use_texture", true)
	_multimesh_instance.material_override = mat
	add_child(_multimesh_instance)

	_visibility_notifier = VisibleOnScreenNotifier3D.new()
	var r = maxf(roaming_radius, 5.0)
	_visibility_notifier.aabb = AABB(Vector3(-r, -vertical_range - 2.0, -r), Vector3(r * 2.0, vertical_range * 2.0 + 4.0, r * 2.0))
	add_child(_visibility_notifier)

	_rad_x.resize(fish_count); _rad_z.resize(fish_count); _phase.resize(fish_count); _orbit_speed.resize(fish_count)
	_px.resize(fish_count); _py.resize(fish_count); _pz.resize(fish_count)
	_dir_x.resize(fish_count); _dir_y.resize(fish_count); _dir_z.resize(fish_count)
	_scl_x.resize(fish_count); _scl_y.resize(fish_count); _scl_z.resize(fish_count)

	for i in range(fish_count):
		var rx = randf_range(1.5, roaming_radius * 0.6)
		var rz = randf_range(1.5, roaming_radius * 0.6)
		var ph = randf() * TAU
		var ospd = randf_range(0.3, 0.6) * (swim_speed / 3.5)

		_rad_x[i] = rx; _rad_z[i] = rz; _phase[i] = ph; _orbit_speed[i] = ospd

		var rand_scl = randf_range(0.85, 1.15)
		var sx = fish_scale.x * rand_scl
		var sy = fish_scale.y * rand_scl
		var sz = fish_scale.z * rand_scl
		_scl_x[i] = sx; _scl_y[i] = sy; _scl_z[i] = sz

		var px = cos(ph) * rx
		var py = sin(ph * 2.0) * (vertical_range * 0.5)
		var pz = sin(ph) * rz
		_px[i] = px; _py[i] = py; _pz[i] = pz

		var fx = -sin(ph) * rx
		var fy = 0.0
		var fz = cos(ph) * rz
		var flen = sqrt(fx * fx + fz * fz)
		if flen > 0.0001:
			fx /= flen; fz /= flen
		else:
			fx = 0.0; fz = -1.0
		_dir_x[i] = fx; _dir_y[i] = fy; _dir_z[i] = fz

		_apply_instance_transform(mm, i, px, py, pz, fx, fy, fz, sx, sy, sz)

func _process(delta: float) -> void:
	# Frustum & Camera Distance Culling
	if _visibility_notifier != null and not _visibility_notifier.is_on_screen():
		var camera = get_viewport().get_camera_3d()
		if camera != null:
			var cam_parent = camera.get_parent()
			var cam_pos = cam_parent.global_position if cam_parent is Node3D else camera.global_transform.origin
			if global_position.distance_squared_to(cam_pos) > 14400.0:
				return

	_time_passed += delta

	roam_change_timer -= delta
	if roam_change_timer <= 0.0:
		roam_change_timer = randf_range(4.0, 9.0)
		var rand_offset = Vector3(
			randf_range(-roaming_radius * 0.4, roaming_radius * 0.4),
			0.0,
			randf_range(-roaming_radius * 0.4, roaming_radius * 0.4)
		)
		target_roam_point = global_position + rand_offset

	# Move school center toward target roam point
	var local_target = to_local(target_roam_point)
	_center_x = move_toward(_center_x, local_target.x, delta * (swim_speed * 0.4))
	_center_z = move_toward(_center_z, local_target.z, delta * (swim_speed * 0.4))

	_update_school_positions(delta)

func _update_school_positions(delta: float) -> void:
	var count = _px.size()
	if count == 0 or _multimesh_instance == null or _multimesh_instance.multimesh == null:
		return

	var mm = _multimesh_instance.multimesh

	for i in range(count):
		var t = _time_passed * _orbit_speed[i] + _phase[i]
		var rx = _rad_x[i]
		var rz = _rad_z[i]

		var target_px = _center_x + cos(t) * rx
		var target_pz = _center_z + sin(t) * rz
		var target_py = sin(t * 1.7) * vertical_range

		var cur_px = move_toward(_px[i], target_px, delta * swim_speed * 2.0)
		var cur_py = move_toward(_py[i], target_py, delta * 2.0)
		var cur_pz = move_toward(_pz[i], target_pz, delta * swim_speed * 2.0)

		# Velocity vector for orientation
		var vx = cur_px - _px[i]
		var vy = cur_py - _py[i]
		var vz = cur_pz - _pz[i]

		_px[i] = cur_px
		_py[i] = cur_py
		_pz[i] = cur_pz

		var vlen = sqrt(vx * vx + vy * vy + vz * vz)
		var fx = _dir_x[i]
		var fy = _dir_y[i]
		var fz = _dir_z[i]

		if vlen > 0.0001:
			var n_fx = vx / vlen
			var n_fy = (vy / vlen) * 0.2
			var n_fz = vz / vlen
			var turn = delta * 6.0
			fx = move_toward(fx, n_fx, turn)
			fy = move_toward(fy, n_fy, turn)
			fz = move_toward(fz, n_fz, turn)
			var flen = sqrt(fx * fx + fy * fy + fz * fz)
			if flen > 0.0001:
				fx /= flen; fy /= flen; fz /= flen
			else:
				fx = 0.0; fy = 0.0; fz = -1.0

		_dir_x[i] = fx
		_dir_y[i] = fy
		_dir_z[i] = fz

		_apply_instance_transform(mm, i, cur_px, cur_py, cur_pz, fx, fy, fz, _scl_x[i], _scl_y[i], _scl_z[i])

func _apply_instance_transform(mm: MultiMesh, i: int, px: float, py: float, pz: float, fx: float, fy: float, fz: float, sx: float, sy: float, sz: float) -> void:
	var f_len_sq = fx * fx + fy * fy + fz * fz
	if f_len_sq < 0.0001:
		fx = 0.0; fy = 0.0; fz = -1.0

	var fwd = Vector3(fx, fy, fz).normalized()
	var b_z = -fwd
	var aux = Vector3.FORWARD if absf(b_z.y) > 0.99 else Vector3.UP
	var b_x = aux.cross(b_z).normalized()
	var b_y = b_z.cross(b_x).normalized()

	var fish_basis = Basis(b_x * sx, b_y * sy, b_z * sz)
	mm.set_instance_transform(i, Transform3D(fish_basis, Vector3(px, py, pz)))

static func get_or_create_primitive_fish_mesh() -> ArrayMesh:
	if primitive_fish_mesh_cache != null:
		return primitive_fish_mesh_cache

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var head = Vector3(0.0, 0.0, -0.5)
	var body_top = Vector3(0.0, 0.18, -0.05)
	var body_bottom = Vector3(0.0, -0.18, -0.05)
	var body_left = Vector3(-0.12, 0.0, -0.05)
	var body_right = Vector3(0.12, 0.0, -0.05)
	var tail_base = Vector3(0.0, 0.0, 0.4)
	var tail_top = Vector3(0.0, 0.25, 0.7)
	var tail_bottom = Vector3(0.0, -0.25, 0.7)

	st.set_normal(Vector3(-0.5, 0.5, -0.7).normalized())
	st.add_vertex(head); st.add_vertex(body_top); st.add_vertex(body_left)
	st.set_normal(Vector3(0.5, 0.5, -0.7).normalized())
	st.add_vertex(head); st.add_vertex(body_right); st.add_vertex(body_top)
	st.set_normal(Vector3(-0.5, -0.5, -0.7).normalized())
	st.add_vertex(head); st.add_vertex(body_left); st.add_vertex(body_bottom)
	st.set_normal(Vector3(0.5, -0.5, -0.7).normalized())
	st.add_vertex(head); st.add_vertex(body_bottom); st.add_vertex(body_right)

	st.set_normal(Vector3(0, 1, 0))
	st.add_vertex(body_top); st.add_vertex(tail_base); st.add_vertex(body_left)
	st.add_vertex(body_top); st.add_vertex(body_right); st.add_vertex(tail_base)
	st.set_normal(Vector3(0, -1, 0))
	st.add_vertex(body_bottom); st.add_vertex(body_left); st.add_vertex(tail_base)
	st.add_vertex(body_bottom); st.add_vertex(tail_base); st.add_vertex(body_right)

	st.set_normal(Vector3(1, 0, 0))
	st.add_vertex(tail_base); st.add_vertex(tail_bottom); st.add_vertex(tail_top)
	st.set_normal(Vector3(-1, 0, 0))
	st.add_vertex(tail_base); st.add_vertex(tail_top); st.add_vertex(tail_bottom)

	primitive_fish_mesh_cache = st.commit()
	return primitive_fish_mesh_cache
