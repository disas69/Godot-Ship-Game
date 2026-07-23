class_name VfxPlayer extends Node3D

signal finished(effect: Node3D)

@export var auto_play: bool = true
@export var free_on_finished: bool = true
@export var particles: Array[Node3D] = []
@export var finish_padding: float = 0.05

var playing_particles: Array[Node3D] = []
var is_playing: bool
var play_id: int


func _ready() -> void:
	if auto_play:
		play()


func play() -> void:
	reset_for_pool()
	is_playing = true
	play_id += 1
	var current_play_id := play_id
	var finish_delay := 0.0

	for particle in particles:
		if particle == null:
			continue

		particle.set("emitting", false)
		particle.call("restart")
		particle.set("emitting", true)

		var is_one_shot: bool = particle.get("one_shot") if particle.get("one_shot") != null else false
		if is_one_shot:
			playing_particles.append(particle)
			finish_delay = maxf(finish_delay, get_particle_finish_delay(particle))
			if particle.has_signal("finished"):
				var callable := on_particle_finished.bind(particle)
				if not particle.is_connected("finished", callable):
					particle.connect("finished", callable)

	if playing_particles.is_empty():
		finish()
	else:
		var finish_timer := get_tree().create_timer(finish_delay + finish_padding)
		finish_timer.timeout.connect(on_finish_timer_timeout.bind(current_play_id))


func reset_for_pool() -> void:
	is_playing = false
	play_id += 1

	for particle in playing_particles:
		if particle != null and is_instance_valid(particle):
			if particle.has_signal("finished"):
				var callable := on_particle_finished.bind(particle)
				if particle.is_connected("finished", callable):
					particle.disconnect("finished", callable)

	playing_particles.clear()

	for particle in particles:
		if particle != null and is_instance_valid(particle):
			particle.set("emitting", false)
			particle.call("restart")
			particle.set("emitting", false)


func on_particle_finished(particle: Node3D) -> void:
	if not is_playing:
		return

	if particle.has_signal("finished"):
		var callable := on_particle_finished.bind(particle)
		if particle.is_connected("finished", callable):
			particle.disconnect("finished", callable)

	playing_particles.erase(particle)
	if playing_particles.is_empty():
		finish()


func finish() -> void:
	is_playing = false
	finished.emit(self)
	if free_on_finished:
		queue_free()


func on_finish_timer_timeout(id: int) -> void:
	if is_playing and id == play_id:
		finish()


func get_particle_finish_delay(particle: Node3D) -> float:
	var speed_scale: float = maxf(particle.get("speed_scale") if particle.get("speed_scale") != null else 1.0, 0.001)
	var lifetime: float = particle.get("lifetime") if particle.get("lifetime") != null else 1.0
	var explosiveness: float = particle.get("explosiveness") if particle.get("explosiveness") != null else 0.0
	var emission_duration := lifetime * (2.0 - explosiveness)
	return maxf(emission_duration / speed_scale, 0.0)
