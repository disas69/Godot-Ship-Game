class_name Ship extends FloatablePlayer3D

@export_category("View")
@export var view: Node3D
@export var forward_incline: Vector2
@export var side_incline: Vector3

func _process(delta: float) -> void:
	if !last_move_dir.is_zero_approx():
		incline_view_x(delta)
		incline_view_z(delta)
	else:
		view.rotation_degrees = lerp(view.rotation_degrees, Vector3.ZERO, 5.0 * delta)

	var time: float = Time.get_ticks_msec() / 1000.0
	view.position.y -= sin(time * 4) * idle_wave * delta


func incline_view_x(delta: float) -> void:
	view.rotation_degrees.x = lerp(view.rotation_degrees.x, forward_incline.x, forward_incline.y * delta)
	
	
func incline_view_z(delta: float) -> void:
	var target_z := 0.0
	var incline_speed := 0.0
	var forward = global_transform.basis.z
	var dot = forward.dot(last_move_dir)
	
	if dot > 0.98:
		target_z = 0.0
		incline_speed = 1.0
	else:
		var cross = forward.cross(last_move_dir)

		if cross.y > 0.0:
			target_z = side_incline.x
		else:
			target_z = side_incline.y
		incline_speed = side_incline.z
		
	view.rotation_degrees.z = lerp(view.rotation_degrees.z, target_z, incline_speed * delta)
