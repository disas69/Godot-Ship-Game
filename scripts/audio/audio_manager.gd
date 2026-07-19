extends Node

var library: AudioLibrary = preload("res://resources/libraries/audio_library.tres")

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"

var sfx_map: Dictionary[String, AudioEntry] = {}
var music_map: Dictionary[String, AudioEntry] = {}
var active_music_players: Dictionary[String, AudioStreamPlayer] = {}
var active_sfx_players: Array[AudioStreamPlayer3D] = []
var music_bus: StringName = MUSIC_BUS
var sfx_bus: StringName = SFX_BUS
var music_root: Node
var sfx_player_pool: ObjectPool
var sfx_pool_root: Node3D


func _ready() -> void:
	music_bus = resolve_bus_name(MUSIC_BUS, &"music")
	sfx_bus = resolve_bus_name(SFX_BUS, &"sfx")
	rebuild_audio_map()
	ensure_music_root()
	ensure_sfx_pool_root()
	ensure_sfx_player_pool()
	sfx_player_pool.prewarm(library.sfx_preload_count)


func play_music(key: String) -> void:
	var entry := get_music_entry_or_warn(key)
	if entry == null:
		return
	var player := get_or_create_music_player(key)
	if player == null:
		return
	player.stream = entry.stream
	player.volume_db = entry.volume
	player.pitch_scale = entry.pitch_scale
	player.play()


func stop_music(key: String = "") -> void:
	if key.is_empty():
		for player_key in active_music_players.keys():
			stop_music(player_key)
		return

	var player := active_music_players.get(key) as AudioStreamPlayer
	if player == null:
		return
	player.stop()
	player.stream = null


func play_sfx(key: String, world_position: Vector3) -> void:
	play_sfx_internal(key, world_position)


func play(key: String) -> void:
	play_sfx(key, Vector3.ZERO)


func stop_sfx(key: String = "") -> void:
	var players: Array[AudioStreamPlayer3D] = active_sfx_players.duplicate()
	for player in players:
		if not is_instance_valid(player):
			continue
		if key.is_empty() or String(player.get_meta("audio_key", "")) == key:
			release_sfx_player(player, true)


func resolve_bus_name(primary: StringName, fallback: StringName) -> StringName:
	if AudioServer.get_bus_index(primary) != -1:
		return primary
	if AudioServer.get_bus_index(fallback) != -1:
		return fallback
	push_warning("Missing bus '%s' (or fallback '%s'). Using '%s'." % [primary, fallback, primary])
	return primary


func rebuild_audio_map() -> void:
	sfx_map.clear()
	music_map.clear()
	if library == null:
		push_warning("Audio library is not assigned.")
		return

	add_entries_to_map(library.sfx_entries, sfx_map, "SFX")
	add_entries_to_map(library.music_entries, music_map, "music")


func add_entries_to_map(entries: Array[AudioEntry], target_map: Dictionary[String, AudioEntry], entry_type: String) -> void:
	for entry in entries:
		if entry == null:
			continue
		if entry.key.is_empty():
			continue
		if entry.stream == null:
			push_warning("%s audio entry '%s' has no stream assigned." % [entry_type, entry.key])
			continue
		target_map[entry.key] = entry


func ensure_music_root() -> void:
	var existing := get_node_or_null("Music")
	if existing != null:
		music_root = existing
	else:
		music_root = Node.new()
		music_root.name = "Music"
		add_child(music_root)

	for child in music_root.get_children():
		if child is AudioStreamPlayer:
			var player := child as AudioStreamPlayer
			player.bus = music_bus
			if player.has_meta("audio_key"):
				active_music_players[String(player.get_meta("audio_key"))] = player


func ensure_sfx_pool_root() -> void:
	if sfx_pool_root != null and is_instance_valid(sfx_pool_root):
		return

	sfx_pool_root = Node3D.new()
	sfx_pool_root.name = "SfxPool"
	sfx_pool_root.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(sfx_pool_root)


func ensure_sfx_player_pool() -> void:
	if sfx_player_pool != null:
		return

	sfx_player_pool = ObjectPool.new(
		create_sfx_player,
		reset_sfx_player_for_pool,
		discard_sfx_player,
		library.max_sfx_pool_size
	)


func get_sfx_entry_or_warn(key: String) -> AudioEntry:
	var entry := sfx_map.get(key) as AudioEntry
	if entry == null:
		push_warning("Missing SFX audio key: " + key)
	return entry


func get_music_entry_or_warn(key: String) -> AudioEntry:
	var entry := music_map.get(key) as AudioEntry
	if entry == null:
		push_warning("Missing music audio key: " + key)
	return entry


func play_sfx_internal(key: String, world_position: Vector3) -> void:
	var entry := get_sfx_entry_or_warn(key)
	if entry == null:
		return

	var player := sfx_player_pool.acquire() as AudioStreamPlayer3D
	if player == null:
		return

	move_sfx_player_to_parent(player, get_sfx_playback_parent())

	player.stream = entry.stream
	player.bus = sfx_bus
	player.volume_db = entry.volume
	player.unit_size = entry.unit_size
	player.pitch_scale = entry.pitch_scale
	player.max_distance = entry.max_distance
	player.top_level = true
	player.global_position = world_position
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.set_meta("audio_key", key)

	active_sfx_players.append(player)
	player.play()


func get_or_create_music_player(key: String) -> AudioStreamPlayer:
	var existing := active_music_players.get(key) as AudioStreamPlayer
	if existing != null and is_instance_valid(existing):
		return existing

	var player := AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.bus = music_bus
	player.set_meta("audio_key", key)
	music_root.add_child(player)
	active_music_players[key] = player
	return player


func on_sfx_finished(player: AudioStreamPlayer3D) -> void:
	if not is_instance_valid(player):
		return
	release_sfx_player(player, false)


func release_sfx_player(player: AudioStreamPlayer3D, stop_playback: bool) -> void:
	if stop_playback and player.playing:
		player.stop()
	active_sfx_players.erase(player)
	if is_instance_valid(player):
		sfx_player_pool.release(player)


func create_sfx_player() -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = "SfxPlayer"
	player.bus = sfx_bus
	player.top_level = true
	player.finished.connect(on_sfx_finished.bind(player))
	return player


func get_sfx_playback_parent() -> Node:
	if GameManager.instance != null:
		var active_game := GameManager.instance.active_game
		if active_game != null and is_instance_valid(active_game):
			return active_game

	var current_scene := get_tree().current_scene
	if current_scene is Node3D:
		return current_scene

	return self


func reset_sfx_player_for_pool(player: AudioStreamPlayer3D) -> void:
	if player.playing:
		player.stop()

	player.stream = null
	player.volume_db = 0.0
	player.unit_size = 10.0
	player.pitch_scale = 1.0
	player.max_distance = 0.0
	player.remove_meta("audio_key")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	move_sfx_player_to_parent(player, sfx_pool_root)


func discard_sfx_player(player: AudioStreamPlayer3D) -> void:
	if is_instance_valid(player):
		player.queue_free()


func move_sfx_player_to_parent(player: AudioStreamPlayer3D, parent: Node) -> void:
	if player.get_parent() == parent:
		return
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	parent.add_child(player)
