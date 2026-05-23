class_name SceneManager extends Node

@export var root: Node

var active_scene: Node


func _ready() -> void:
	if root == null:
		root = self


func load_scene(scene: PackedScene, unload_current := true) -> Node:
	if scene == null:
		push_warning("SceneManager: scene is not assigned.")
		return null

	if unload_current:
		unload_active_scene()

	var scene_instance := scene.instantiate()
	if scene_instance == null:
		push_warning("SceneManager: failed to instantiate scene.")
		return null

	set_active_scene(scene_instance)
	root.add_child(active_scene)
	return active_scene


func unload_active_scene() -> void:
	if active_scene == null or not is_instance_valid(active_scene):
		active_scene = null
		return

	active_scene.queue_free()
	active_scene = null


func set_active_scene(scene: Node) -> void:
	active_scene = scene


func get_active_scene() -> Node:
	if active_scene != null and is_instance_valid(active_scene):
		return active_scene

	active_scene = null
	return null
