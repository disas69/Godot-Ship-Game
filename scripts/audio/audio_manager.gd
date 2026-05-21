extends Node

var library: AudioLibrary = preload("res://audio/audio_library.tres")

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"

@export_range(0, 64, 1) var sfx_preload_count: int = 4
@export_range(0, 128, 1) var max_sfx_pool_size: int = 32

var audio_map: Dictionary[String, AudioStream] = {}
var music_player: AudioStreamPlayer
var active_sfx_players: Array[AudioStreamPlayer3D] = []
var music_bus: StringName = MUSIC_BUS
var sfx_bus: StringName = SFX_BUS
var sfx_player_pool: ObjectPool
var sfx_pool_root: Node3D


func _ready() -> void:
	music_bus = resolve_bus_name(MUSIC_BUS, &"music")
	sfx_bus = resolve_bus_name(SFX_BUS, &"sfx")
	rebuild_audio_map()
	ensure_music_player()
	ensure_sfx_pool_root()
	ensure_sfx_player_pool()
	sfx_player_pool.prewarm(sfx_preload_count)


func play_music(key: String) -> void:
	var stream := get_stream_or_warn(key)
	if stream == null:
		return
	music_player.stream = stream
	music_player.play()


func stop_music() -> void:
	if music_player != null:
		music_player.stop()


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
	audio_map.clear()
	if library == null:
		push_warning("Audio library is not assigned.")
		return
	for entry in library.entries:
		if entry == null:
			continue
		if entry.key.is_empty():
			continue
		if entry.stream == null:
			push_warning("Audio entry '%s' has no stream assigned." % entry.key)
			continue
		audio_map[entry.key] = entry.stream


func ensure_music_player() -> void:
	var existing := get_node_or_null("Music")
	if existing is AudioStreamPlayer:
		music_player = existing as AudioStreamPlayer
	else:
		music_player = AudioStreamPlayer.new()
		music_player.name = "Music"
		add_child(music_player)
	music_player.bus = music_bus


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
		max_sfx_pool_size
	)


func get_stream_or_warn(key: String) -> AudioStream:
	var stream := audio_map.get(key) as AudioStream
	if stream == null:
		push_warning("Missing audio key: " + key)
	return stream


func play_sfx_internal(key: String, world_position: Vector3) -> void:
	var stream := get_stream_or_warn(key)
	if stream == null:
		return

	var player := sfx_player_pool.acquire() as AudioStreamPlayer3D
	if player == null:
		return

	move_sfx_player_to_parent(player, self)

	player.stream = stream
	player.bus = sfx_bus
	player.top_level = true
	player.global_position = world_position
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.set_meta("audio_key", key)

	active_sfx_players.append(player)
	var finished_callback := on_sfx_finished.bind(player)
	if not player.finished.is_connected(finished_callback):
		player.finished.connect(finished_callback)
	player.play()


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
	return player


func reset_sfx_player_for_pool(player: AudioStreamPlayer3D) -> void:
	if player.playing:
		player.stop()

	player.stream = null
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
