class_name Water extends FluidArea3D


func _on_body_entered(body: Node3D) -> void:
	if body is CannonBall:
		var cannonBall: CannonBall = body as CannonBall
		cannonBall.on_water_entered(body.global_position)
