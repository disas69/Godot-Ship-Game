class_name CannonBall extends RigidBody3D

@export var max_lifetime: float = 5.0
@export var cannon_view: Node3D

var shooter: Ship
var release_callback: Callable
var lifetime_remaining: float
var is_released: bool
var default_gravity_scale: float
var default_cannon_view_scale: Vector3
var scale_tween: Tween
var default_state_cached: bool


func _ready() -> void:
	cache_default_state()
	if is_zero_approx(lifetime_remaining):
		lifetime_remaining = max_lifetime


func _process(delta: float) -> void:
	lifetime_remaining -= delta
	if lifetime_remaining <= 0.0:
		release()


func _on_body_entered(body: Node) -> void:	
	if is_released:
		return

	var ship: Ship = body as Ship
	if ship != null and ship != shooter and (shooter == null or shooter.can_target_ship(ship)):
		ship.take_hit(linear_velocity, shooter)
		play_hit(global_position)
	
	release()


func set_shooter(ship: Ship) -> void:
	clear_shooter()
	shooter = ship
	if shooter:
		add_collision_exception_with(shooter)


func on_water_entered(pos: Vector3) -> void:
	if is_released:
		return

	linear_velocity *= 0.2
	gravity_scale = 0.1
	
	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()

	scale_tween = create_tween()
	scale_tween.tween_property(cannon_view, "scale", Vector3.ONE * 0.5, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	play_water_splash(pos)


func set_release_callback(callback: Callable) -> void:
	release_callback = callback


func reset_for_spawn() -> void:
	cache_default_state()
	is_released = false
	lifetime_remaining = max_lifetime
	gravity_scale = default_gravity_scale
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	freeze = false
	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()
	scale_tween = null
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if cannon_view != null:
		cannon_view.scale = default_cannon_view_scale


func reset_for_pool() -> void:
	cache_default_state()
	is_released = true
	clear_shooter()
	lifetime_remaining = max_lifetime
	gravity_scale = default_gravity_scale
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = true
	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()
	scale_tween = null
	if cannon_view != null:
		cannon_view.scale = default_cannon_view_scale
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func release() -> void:
	if is_released:
		return

	is_released = true
	if release_callback.is_valid():
		release_callback.call(self)
	else:
		queue_free()


func clear_shooter() -> void:
	if shooter != null and is_instance_valid(shooter):
		remove_collision_exception_with(shooter)
	shooter = null


func cache_default_state() -> void:
	if default_state_cached:
		return

	default_state_cached = true
	default_gravity_scale = gravity_scale
	if cannon_view != null:
		default_cannon_view_scale = cannon_view.scale


func play_water_splash(pos: Vector3) -> void:
	VfxManager.spawn("water_splash", pos)
	AudioManager.play_sfx("water_splash", pos)
	

func play_hit(pos: Vector3) -> void:
	VfxManager.spawn("cannon_hit", pos)
