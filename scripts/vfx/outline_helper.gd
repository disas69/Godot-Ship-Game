class_name OutlineHelper extends Object

const OUTLINE_MATERIAL_TEMPLATE := preload("res://materials/outline.tres")


static func create_outline_material(color: Color = Color.BLACK, thickness: float = 0.075, template: ShaderMaterial = null) -> ShaderMaterial:
	var base_template := template if template != null else OUTLINE_MATERIAL_TEMPLATE
	var mat := base_template.duplicate(true) as ShaderMaterial
	mat.set_shader_parameter(&"outline_color", color)
	mat.set_shader_parameter(&"outline_thickness", thickness)
	return mat


static func find_geometry_instances(root_node: Node) -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	if root_node == null:
		return result
	_collect_geometry_instances(root_node, result)
	return result


static func _collect_geometry_instances(node: Node, result: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D and not (node is Sprite3D or node is SpriteBase3D or node is GPUParticles3D or node is CPUParticles3D):
		result.append(node as GeometryInstance3D)
	for child in node.get_children():
		_collect_geometry_instances(child, result)


static func apply_outline_to_nodes(nodes: Array, outline_material: ShaderMaterial) -> void:
	for item in nodes:
		if item == null:
			continue
		if item is GeometryInstance3D:
			apply_outline_to_geometry(item as GeometryInstance3D, outline_material)
		elif item is Node:
			var geoms := find_geometry_instances(item as Node)
			for geom in geoms:
				apply_outline_to_geometry(geom, outline_material)


static func apply_outline_to_geometry(geom: GeometryInstance3D, outline_material: ShaderMaterial) -> void:
	if geom == null or outline_material == null:
		return
	
	if geom.material_overlay == null:
		geom.material_overlay = outline_material
	else:
		# Chain outline onto the existing material_overlay's next_pass
		var current: Material = geom.material_overlay
		while current.next_pass != null and current.next_pass != outline_material:
			current = current.next_pass
		if current.next_pass == null:
			current.next_pass = outline_material


static func update_outline_color(outline_material: ShaderMaterial, color: Color) -> void:
	if outline_material != null:
		outline_material.set_shader_parameter(&"outline_color", color)


static func update_outline_thickness(outline_material: ShaderMaterial, thickness: float) -> void:
	if outline_material != null:
		outline_material.set_shader_parameter(&"outline_thickness", thickness)
