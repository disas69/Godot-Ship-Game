class_name CannonBall extends RigidBody3D

@export var max_lifetime: float = 5.0
@export var cannon_view: Node3D
@export var water_splash_particles: PackedScene


func _ready() -> void:
	pass # Replace with function body.


func _process(delta: float) -> void:
	max_lifetime -= delta
	if max_lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	print("Bullet hit: ", body.name)
	
	var ship: Ship = body as Ship
	ship.take_hit()
	
	queue_free()


func on_water_entered(pos: Vector3) -> void:
	linear_velocity *= 0.2
	gravity_scale = 0.1
	
	var scale_tween: Tween = create_tween()
	scale_tween.tween_property(cannon_view, "scale", Vector3.ONE * 0.5, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	play_water_splash(pos)


func play_water_splash(pos: Vector3) -> void:
	var splash: Node3D = water_splash_particles.instantiate() as Node3D
	splash.global_position = pos
	get_tree().current_scene.add_child(splash)
	splash.get_node("GPUParticles3D").emitting = true
	await splash.get_node("GPUParticles3D").finished
	splash.queue_free()
	
