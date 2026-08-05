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

class FishInstance:
	var node: Node3D
	var velocity: Vector3
	var mesh_inst: MeshInstance3D

var fish_list: Array[FishInstance] = []
var target_roam_point: Vector3 = Vector3.ZERO
var roam_change_timer: float = 0.0

static var primitive_fish_mesh_cache: ArrayMesh = null

func _ready() -> void:
	target_roam_point = global_position
	spawn_fish_flock()

func spawn_fish_flock() -> void:
	for fish in fish_list:
		if is_instance_valid(fish.node):
			fish.node.queue_free()
	fish_list.clear()

	var fish_mesh = custom_fish_mesh
	if fish_mesh == null and custom_fish_scene == null:
		fish_mesh = get_or_create_primitive_fish_mesh()

	var fish_shader = preload("res://shaders/fish_wiggle.gdshader")

	for i in range(fish_count):
		var fish_data = FishInstance.new()
		var fish_node: Node3D = null

		if custom_fish_scene != null:
			fish_node = custom_fish_scene.instantiate() as Node3D
		else:
			var mi = MeshInstance3D.new()
			mi.mesh = fish_mesh
			var mat = ShaderMaterial.new()
			mat.shader = fish_shader
			mat.set_shader_parameter("albedo_color", fish_color)
			mat.set_shader_parameter("swim_speed", randf_range(6.0, 10.0))
			mat.set_shader_parameter("wiggle_amplitude", 0.25)
			mat.set_shader_parameter("phase_offset", randf() * TAU)
			if custom_fish_texture != null:
				mat.set_shader_parameter("albedo_texture", custom_fish_texture)
				mat.set_shader_parameter("use_texture", true)
			mi.material_override = mat
			fish_data.mesh_inst = mi
			fish_node = mi

		fish_node.scale = fish_scale * randf_range(0.85, 1.15)
		add_child(fish_node)

		# Initial local position relative to FishFlock node position
		var offset = Vector3(
			randf_range(-roaming_radius * 0.5, roaming_radius * 0.5),
			randf_range(-vertical_range * 0.5, vertical_range * 0.5),
			randf_range(-roaming_radius * 0.5, roaming_radius * 0.5)
		)
		fish_node.position = offset
		
		var angle = randf() * TAU
		fish_data.velocity = Vector3(cos(angle), randf_range(-0.05, 0.05), sin(angle)).normalized() * swim_speed
		fish_data.node = fish_node

		fish_list.append(fish_data)

func _process(delta: float) -> void:
	roam_change_timer -= delta
	if roam_change_timer <= 0.0:
		roam_change_timer = randf_range(4.0, 9.0)
		var rand_offset = Vector3(
			randf_range(-roaming_radius * 0.6, roaming_radius * 0.6),
			0.0,
			randf_range(-roaming_radius * 0.6, roaming_radius * 0.6)
		)
		target_roam_point = global_position + rand_offset

	update_boids(delta)

func update_boids(delta: float) -> void:
	var count = fish_list.size()
	if count == 0:
		return

	var base_y = global_position.y

	for i in range(count):
		var fish = fish_list[i]
		var pos = fish.node.global_position
		var vel = fish.velocity

		var cohesion := Vector3.ZERO
		var separation := Vector3.ZERO
		var alignment := Vector3.ZERO
		var neighbors: int = 0

		for j in range(count):
			if i == j:
				continue
			var other = fish_list[j]
			var dist = pos.distance_to(other.node.global_position)

			if dist < neighbor_distance:
				cohesion += other.node.global_position
				alignment += other.velocity
				neighbors += 1

				if dist < separation_distance and dist > 0.001:
					separation += (pos - other.node.global_position).normalized() / dist

		var accel := Vector3.ZERO

		if neighbors > 0:
			cohesion = (cohesion / float(neighbors) - pos).normalized() * swim_speed
			alignment = (alignment / float(neighbors)).normalized() * swim_speed

			accel += (cohesion - vel) * weight_cohesion
			accel += separation * weight_separation * 5.0
			accel += (alignment - vel) * weight_alignment

		# Return towards roaming center on XZ plane
		var target_xz = Vector3(target_roam_point.x, pos.y, target_roam_point.z)
		var dist_to_target = pos.distance_to(target_xz)
		if dist_to_target > roaming_radius:
			var return_dir = (target_xz - pos).normalized() * swim_speed
			accel += (return_dir - vel) * weight_bounds

		# Dampen Y vertical movement so fish swim flat underwater at node Y height
		var y_diff = base_y - pos.y
		accel.y += y_diff * 4.0

		# Apply acceleration
		vel += accel * delta
		
		# Clamp Y velocity to keep swimming horizontal underwater
		vel.y = clamp(vel.y, -0.4, 0.4)

		var horizontal_speed = Vector2(vel.x, vel.z).length()
		if horizontal_speed > max_speed:
			var h_norm = Vector2(vel.x, vel.z).normalized() * max_speed
			vel.x = h_norm.x
			vel.z = h_norm.y
		elif horizontal_speed < swim_speed * 0.5:
			var h_norm = Vector2(vel.x, vel.z).normalized() * (swim_speed * 0.5)
			vel.x = h_norm.x
			vel.z = h_norm.y

		fish.velocity = vel
		fish.node.global_position += vel * delta

		# Strictly clamp global Y position to stay near node Y position
		fish.node.global_position.y = clamp(fish.node.global_position.y, base_y - vertical_range, base_y + vertical_range)

		# Yaw & slight bank rotation (flatten Y component so fish points forward without pitching up into air)
		var look_vel = Vector3(vel.x, vel.y * 0.15, vel.z)
		if look_vel.length_squared() > 0.001:
			var target_rot = Transform3D().looking_at(look_vel, Vector3.UP).basis
			fish.node.basis = fish.node.basis.slerp(target_rot, delta * 6.0)

static func get_or_create_primitive_fish_mesh() -> ArrayMesh:
	if primitive_fish_mesh_cache != null:
		return primitive_fish_mesh_cache

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var head = Vector3(0.0, 0.0, -0.5) # Forward is -Z
	var body_top = Vector3(0.0, 0.18, -0.05)
	var body_bottom = Vector3(0.0, -0.18, -0.05)
	var body_left = Vector3(-0.12, 0.0, -0.05)
	var body_right = Vector3(0.12, 0.0, -0.05)
	var tail_base = Vector3(0.0, 0.0, 0.4) # Backward is +Z
	var tail_top = Vector3(0.0, 0.25, 0.7)
	var tail_bottom = Vector3(0.0, -0.25, 0.7)

	# Head pyramid facing -Z
	st.set_normal(Vector3(-0.5, 0.5, -0.7).normalized())
	st.add_vertex(head); st.add_vertex(body_top); st.add_vertex(body_left)
	st.set_normal(Vector3(0.5, 0.5, -0.7).normalized())
	st.add_vertex(head); st.add_vertex(body_right); st.add_vertex(body_top)
	st.set_normal(Vector3(-0.5, -0.5, -0.7).normalized())
	st.add_vertex(head); st.add_vertex(body_left); st.add_vertex(body_bottom)
	st.set_normal(Vector3(0.5, -0.5, -0.7).normalized())
	st.add_vertex(head); st.add_vertex(body_bottom); st.add_vertex(body_right)

	# Body section to tail base
	st.set_normal(Vector3(0, 1, 0))
	st.add_vertex(body_top); st.add_vertex(tail_base); st.add_vertex(body_left)
	st.add_vertex(body_top); st.add_vertex(body_right); st.add_vertex(tail_base)
	st.set_normal(Vector3(0, -1, 0))
	st.add_vertex(body_bottom); st.add_vertex(body_left); st.add_vertex(tail_base)
	st.add_vertex(body_bottom); st.add_vertex(tail_base); st.add_vertex(body_right)

	# Tail fin (double sided)
	st.set_normal(Vector3(1, 0, 0))
	st.add_vertex(tail_base); st.add_vertex(tail_bottom); st.add_vertex(tail_top)
	st.set_normal(Vector3(-1, 0, 0))
	st.add_vertex(tail_base); st.add_vertex(tail_top); st.add_vertex(tail_bottom)

	primitive_fish_mesh_cache = st.commit()
	return primitive_fish_mesh_cache
