class_name VfxAnimationPlayer extends Node3D

signal finished(effect: Node3D)

@export var auto_play: bool = true
@export var free_on_finished: bool = true
@export var play_animation: StringName = &"play"

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var active_animation: StringName


func _ready() -> void:
	if animation_player == null:
		push_warning("No AnimationPlayer found in VfxAnimationPlayer.")
		return

	animation_player.animation_finished.connect(on_animation_finished)
	if auto_play:
		play()


func play(animation_name: StringName = &"") -> void:
	if animation_player == null:
		return
	if animation_name == &"":
		animation_name = play_animation
	if not animation_player.has_animation(animation_name):
		push_warning("Missing VFX animation: " + String(animation_name))
		finish()
		return

	reset_for_pool()
	active_animation = animation_name
	animation_player.play(animation_name)


func reset_for_pool() -> void:
	if animation_player == null:
		return

	animation_player.stop()
	if animation_player.has_animation(&"RESET"):
		animation_player.play(&"RESET")
		animation_player.advance(0.0)
		animation_player.stop()

	for child in find_children("*", "GPUParticles3D", true, false):
		var particles := child as GPUParticles3D
		particles.emitting = false


func on_animation_finished(animation_name: StringName) -> void:
	if animation_name != active_animation:
		return
	finish()


func finish() -> void:
	finished.emit(self)
	if free_on_finished:
		queue_free()
