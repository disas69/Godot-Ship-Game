class_name VfxPlayer extends Node3D

signal finished(effect: Node3D)

@export var auto_play: bool = true
@export var free_on_finished: bool = true
@export var particles: Array[GPUParticles3D] = []
@export var finish_padding: float = 0.05

var _playing_particles: Array[GPUParticles3D] = []
var _is_playing: bool
var _play_id: int


func _ready() -> void:
	if auto_play:
		play()


func play() -> void:
	reset_for_pool()
	_is_playing = true
	_play_id += 1
	var current_play_id := _play_id
	var finish_delay := 0.0

	for particle in particles:
		if particle == null:
			continue

		particle.emitting = false
		particle.restart()
		particle.emitting = true

		if particle.one_shot:
			_playing_particles.append(particle)
			finish_delay = maxf(finish_delay, _get_particle_finish_delay(particle))
			if not particle.finished.is_connected(_on_particle_finished.bind(particle)):
				particle.finished.connect(_on_particle_finished.bind(particle))

	if _playing_particles.is_empty():
		_finish()
	else:
		var finish_timer := get_tree().create_timer(finish_delay + finish_padding)
		finish_timer.timeout.connect(_on_finish_timer_timeout.bind(current_play_id))


func reset_for_pool() -> void:
	_is_playing = false
	_play_id += 1

	for particle in _playing_particles:
		if particle != null and is_instance_valid(particle):
			var callable := _on_particle_finished.bind(particle)
			if particle.finished.is_connected(callable):
				particle.finished.disconnect(callable)

	_playing_particles.clear()

	for particle in particles:
		if particle != null and is_instance_valid(particle):
			particle.emitting = false


func _on_particle_finished(particle: GPUParticles3D) -> void:
	if not _is_playing:
		return

	var callable := _on_particle_finished.bind(particle)
	if particle.finished.is_connected(callable):
		particle.finished.disconnect(callable)

	_playing_particles.erase(particle)
	if _playing_particles.is_empty():
		_finish()


func _finish() -> void:
	_is_playing = false
	finished.emit(self)
	if free_on_finished:
		queue_free()


func _on_finish_timer_timeout(play_id: int) -> void:
	if _is_playing and _play_id == play_id:
		_finish()


func _get_particle_finish_delay(particle: GPUParticles3D) -> float:
	var speed_scale := maxf(particle.speed_scale, 0.001)
	var emission_duration := particle.lifetime * (2.0 - particle.explosiveness)
	return maxf(emission_duration / speed_scale, 0.0)
