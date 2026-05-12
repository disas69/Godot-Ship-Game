class_name VfxAnimationPlayer extends Node3D

@onready var animatio_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	if animatio_player:
		animatio_player.play("play")
		await animatio_player.animation_finished
		queue_free()
	else:
		print("No AnimationPlayer found in VfxAnimationPlayer.")
