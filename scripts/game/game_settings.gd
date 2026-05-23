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


func get_game_scene() -> PackedScene:
	for scene in game_scenes:
		if scene == null:
			continue

		var scene_instance := scene.instantiate()
		var game_instance := scene_instance as Game
		if game_instance != null:
			game_instance.free()
			return scene
		if scene_instance != null:
			scene_instance.free()

	return null
