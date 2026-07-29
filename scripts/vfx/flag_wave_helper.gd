class_name FlagWaveHelper extends Object

const FLAG_WAVE_SHADER := preload("res://shaders/flag_wave.gdshader")
const DEFAULT_TEXTURE := preload("res://assets/kenney_pirate-kit/Models/GLB format/Textures/colormap.png")


static func apply_flag_wave(
	root_node: Node,
	wave_amplitude: float = 0.15,
	wave_speed: float = 4.0,
	wave_frequency: float = 3.0,
	height_threshold: float = 0.4,
	height_falloff: float = 0.6
) -> void:
	if root_node == null:
		return

	var flag_meshes: Array[MeshInstance3D] = []
	_collect_flag_meshes(root_node, flag_meshes)

	for mesh_inst in flag_meshes:
		_apply_wave_to_mesh(
			mesh_inst,
			wave_amplitude,
			wave_speed,
			wave_frequency,
			height_threshold,
			height_falloff
		)


static func _collect_flag_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var name_lower := node.name.to_lower()
		var parent_name_lower := node.get_parent().name.to_lower() if node.get_parent() != null else ""
		if "flag" in name_lower or "flag" in parent_name_lower:
			result.append(node as MeshInstance3D)
	
	for child in node.get_children():
		_collect_flag_meshes(child, result)


static func _apply_wave_to_mesh(
	mesh_inst: MeshInstance3D,
	wave_amplitude: float,
	wave_speed: float,
	wave_frequency: float,
	height_threshold: float,
	height_falloff: float
) -> void:
	if mesh_inst == null:
		return

	var wave_mat := ShaderMaterial.new()
	wave_mat.shader = FLAG_WAVE_SHADER
	wave_mat.set_shader_parameter(&"albedo_texture", DEFAULT_TEXTURE)
	wave_mat.set_shader_parameter(&"wave_speed", wave_speed)
	wave_mat.set_shader_parameter(&"wave_frequency", wave_frequency)
	wave_mat.set_shader_parameter(&"wave_amplitude", wave_amplitude)
	wave_mat.set_shader_parameter(&"height_threshold", height_threshold)
	wave_mat.set_shader_parameter(&"height_falloff", height_falloff)

	mesh_inst.material_override = wave_mat

	# Update outline overlay shader parameters if present on mesh or next_pass chain
	var current: Material = mesh_inst.material_overlay
	while current != null:
		if current is ShaderMaterial:
			var smat := current as ShaderMaterial
			smat.set_shader_parameter(&"wave_speed", wave_speed)
			smat.set_shader_parameter(&"wave_frequency", wave_frequency)
			smat.set_shader_parameter(&"wave_amplitude", wave_amplitude)
			smat.set_shader_parameter(&"height_threshold", height_threshold)
			smat.set_shader_parameter(&"height_falloff", height_falloff)
		current = current.next_pass
