class_name WebEnvironmentAdjuster extends WorldEnvironment

@export var directional_light: DirectionalLight3D


func _ready() -> void:
	if is_web_platform():
		apply_web_overrides()


func is_web_platform() -> bool:
	return OS.has_feature("web") \
		or OS.get_name() == "Web" \
		or DisplayServer.get_name() == "web" \
		or RenderingServer.get_rendering_device() == null


func apply_web_overrides() -> void:
	if environment != null:
		environment = environment.duplicate()
		environment.ambient_light_energy = 0.75
		environment.tonemap_exposure = 0.8
		environment.adjustment_enabled = true
		environment.adjustment_contrast = 1.05
		environment.adjustment_saturation = 1.05

	if directional_light == null and get_parent() != null:
		directional_light = get_parent().get_node_or_null("Sun") as DirectionalLight3D

	if directional_light != null:
		directional_light.light_energy = 0.85

	# Water override for Web builds ONLY
	var water_mesh_node: MeshInstance3D = null
	if get_parent() != null:
		water_mesh_node = get_parent().get_node_or_null("Water/View") as MeshInstance3D
		if water_mesh_node == null and get_parent().get_parent() != null:
			water_mesh_node = get_parent().get_parent().get_node_or_null("Water/View") as MeshInstance3D

	if water_mesh_node != null and water_mesh_node.mesh != null:
		var mat := water_mesh_node.mesh.material as ShaderMaterial
		if mat != null:
			mat = mat.duplicate() as ShaderMaterial
			water_mesh_node.mesh = water_mesh_node.mesh.duplicate()
			water_mesh_node.mesh.material = mat
			mat.set_shader_parameter("_DepthGradientShallow", Color(0.20, 0.60, 0.78, 0.725))
			mat.set_shader_parameter("_DepthGradientDeep", Color(0.12, 0.42, 0.52, 0.792))
			mat.set_shader_parameter("foam_color", Color(0.85, 0.92, 1.0, 0.4))
