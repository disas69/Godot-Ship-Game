class_name GameSettings extends Resource

@export_category("Scenes")
@export var game_scenes: Array[PackedScene] = []
@export var initial_scene_index := 0

@export_category("Game Setup")
@export var game_mode: GameMode


func get_initial_scene() -> PackedScene:
	if game_scenes.is_empty():
		return null

	var clamped_index: int = clampi(initial_scene_index, 0, game_scenes.size() - 1)
	return game_scenes[clamped_index]
