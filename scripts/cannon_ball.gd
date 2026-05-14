class_name CannonBall extends RigidBody3D

@export var max_lifetime: float = 5.0
@export var cannon_view: Node3D
@export var water_splash_particles: PackedScene
@export var hit_particles: PackedScene

var shooter: Ship


func _process(delta: float) -> void:
	max_lifetime -= delta
	if max_lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:	
	var ship: Ship = body as Ship
	if ship != null and ship != shooter and (shooter == null or shooter.can_target_ship(ship)):
		ship.take_hit(linear_velocity)
		play_hit(global_position)
	
	queue_free()


func set_shooter(ship: Ship) -> void:
	shooter = ship
	if shooter:
		add_collision_exception_with(shooter)


func on_water_entered(pos: Vector3) -> void:
	linear_velocity *= 0.2
	gravity_scale = 0.1
	
	var scale_tween: Tween = create_tween()
	scale_tween.tween_property(cannon_view, "scale", Vector3.ONE * 0.5, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	play_water_splash(pos)


func play_water_splash(pos: Vector3) -> void:
	var splash: Node3D = water_splash_particles.instantiate() as Node3D
	get_tree().current_scene.add_child(splash)
	splash.global_position = pos
	

func play_hit(pos: Vector3) -> void:
	var hit: Node3D = hit_particles.instantiate() as Node3D
	get_tree().current_scene.add_child(hit)
	hit.global_position = pos
