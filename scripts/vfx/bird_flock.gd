class_name BirdFlock
extends Node3D

@export_group("Custom Assets")
@export var custom_bird_scene: PackedScene = null
@export var custom_bird_mesh: Mesh = null
@export var custom_bird_texture: Texture2D = null

@export_group("Flock Configuration")
@export var bird_count: int = 9
@export var flight_speed: float = 14.0
@export var formation_spread: Vector3 = Vector3(1.5, 0.5, 1.5)
@export var v_formation_angle: float = 45.0
@export var bird_scale: Vector3 = Vector3(0.45, 0.45, 0.45)
@export var bird_color: Color = Color(0.2, 0.23, 0.28, 1.0)

var flight_direction: Vector3 = Vector3.FORWARD
var target_position: Vector3 = Vector3.ZERO
var total_distance: float = 100.0
var distance_traveled: float = 0.0

static var primitive_bird_mesh_cache: ArrayMesh = null

func _ready() -> void:
	setup_flock()

func setup_flock() -> void:
	for child in get_children():
		child.queue_free()

	var bird_mesh: Mesh = custom_bird_mesh
	if bird_mesh == null and custom_bird_scene == null:
		bird_mesh = get_or_create_primitive_mesh()

	var bird_shader = preload("res://shaders/bird_wing.gdshader")

	for i in range(bird_count):
		var bird_node: Node3D = null

		if custom_bird_scene != null:
			bird_node = custom_bird_scene.instantiate() as Node3D
		else:
			var mesh_inst = MeshInstance3D.new()
			mesh_inst.mesh = bird_mesh
			
			var mat = ShaderMaterial.new()
			mat.shader = bird_shader
			mat.set_shader_parameter("albedo_color", bird_color)
			mat.set_shader_parameter("flap_speed", randf_range(11.0, 15.0))
			mat.set_shader_parameter("flap_amplitude", 0.4)
			mat.set_shader_parameter("phase_offset", randf() * TAU)
			if custom_bird_texture != null:
				mat.set_shader_parameter("albedo_texture", custom_bird_texture)
				mat.set_shader_parameter("use_texture", true)

			mesh_inst.material_override = mat
			bird_node = mesh_inst

		bird_node.scale = bird_scale * randf_range(0.85, 1.15)
		add_child(bird_node)

		# Position in V-formation
		var local_offset := Vector3.ZERO
		if i > 0:
			var side: float = 1.0 if (i % 2 == 1) else -1.0
			var index_on_side: int = int(ceil(i / 2.0))
			var rad = deg_to_rad(v_formation_angle)
			local_offset.x = side * index_on_side * formation_spread.x
			local_offset.z = index_on_side * formation_spread.z * tan(rad) # Trailing behind (+Z)
			local_offset.y = (randf() - 0.5) * formation_spread.y

		bird_node.position = local_offset

func _process(delta: float) -> void:
	if flight_direction != Vector3.ZERO:
		var move_amount = flight_speed * delta
		global_position += flight_direction * move_amount
		distance_traveled += move_amount

		if flight_direction.length_squared() > 0.001:
			look_at(global_position + flight_direction, Vector3.UP)

		# Despawn when flight path complete and far enough from active camera
		if distance_traveled >= total_distance:
			var camera = get_viewport().get_camera_3d()
			if camera != null:
				var dist_to_cam = global_position.distance_to(camera.global_transform.origin)
				# Only free when safely beyond camera view distance (100+ units)
				if dist_to_cam > 90.0:
					queue_free()
			else:
				queue_free()

func start_flight(start_pos: Vector3, end_pos: Vector3, speed: float = 14.0) -> void:
	global_position = start_pos
	target_position = end_pos
	flight_speed = speed
	var delta_pos = end_pos - start_pos
	total_distance = delta_pos.length()
	flight_direction = delta_pos.normalized()
	distance_traveled = 0.0

static func get_or_create_primitive_mesh() -> ArrayMesh:
	if primitive_bird_mesh_cache != null:
		return primitive_bird_mesh_cache

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var left_tip = Vector3(-0.75, 0.0, 0.0)
	var right_tip = Vector3(0.75, 0.0, 0.0)
	var head = Vector3(0.0, 0.02, -0.45) # Forward is -Z
	var tail = Vector3(0.0, -0.05, 0.35) # Backward is +Z

	# Left wing top
	st.set_normal(Vector3(0, 1, 0))
	st.set_uv(Vector2(0, 0))
	st.add_vertex(left_tip)
	st.set_uv(Vector2(0.5, 1))
	st.add_vertex(head)
	st.set_uv(Vector2(0.5, 0))
	st.add_vertex(tail)

	# Right wing top
	st.set_normal(Vector3(0, 1, 0))
	st.set_uv(Vector2(1, 0))
	st.add_vertex(right_tip)
	st.set_uv(Vector2(0.5, 0))
	st.add_vertex(tail)
	st.set_uv(Vector2(0.5, 1))
	st.add_vertex(head)

	primitive_bird_mesh_cache = st.commit()
	return primitive_bird_mesh_cache
