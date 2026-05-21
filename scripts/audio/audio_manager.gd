extends Node

var library: AudioLibrary = preload("res://audio/audio_library.tres")

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"

var audio_map: Dictionary[String, AudioStream] = {}
var music_player: AudioStreamPlayer
var active_sfx_players: Array[AudioStreamPlayer3D] = []
var music_bus: StringName = MUSIC_BUS
var sfx_bus: StringName = SFX_BUS


func _ready() -> void:
	music_bus = _resolve_bus_name(MUSIC_BUS, &"music")
	sfx_bus = _resolve_bus_name(SFX_BUS, &"sfx")
	_rebuild_audio_map()
	_ensure_music_player()


func set_library(new_library: AudioLibrary) -> void:
	library = new_library
	_rebuild_audio_map()


func play_music(key: String) -> void:
	var stream := _get_stream_or_warn(key)
	if stream == null:
		return
	music_player.stream = stream
	music_player.play()


func stop_music() -> void:
	if music_player != null:
		music_player.stop()


func play_sfx(key: String, world_position: Vector3) -> void:
	_play_sfx_internal(key, world_position)


func play(key: String) -> void:
	play_sfx(key, Vector3.ZERO)
	

func stop_sfx(key: String = "") -> void:
	var players: Array[AudioStreamPlayer3D] = active_sfx_players.duplicate()
	for player in players:
		if not is_instance_valid(player):
			continue
		if key.is_empty() or String(player.get_meta("audio_key", "")) == key:
			_release_sfx_player(player, true)


func _resolve_bus_name(primary: StringName, fallback: StringName) -> StringName:
	if AudioServer.get_bus_index(primary) != -1:
		return primary
	if AudioServer.get_bus_index(fallback) != -1:
		return fallback
	push_warning("Missing bus '%s' (or fallback '%s'). Using '%s'." % [primary, fallback, primary])
	return primary


func _rebuild_audio_map() -> void:
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


func _ensure_music_player() -> void:
	var existing := get_node_or_null("Music")
	if existing is AudioStreamPlayer:
		music_player = existing as AudioStreamPlayer
	else:
		music_player = AudioStreamPlayer.new()
		music_player.name = "Music"
		add_child(music_player)
	music_player.bus = music_bus


func _get_stream_or_warn(key: String) -> AudioStream:
	var stream := audio_map.get(key) as AudioStream
	if stream == null:
		push_warning("Missing audio key: " + key)
	return stream


func _play_sfx_internal(key: String, world_position: Vector3) -> void:
	var stream := _get_stream_or_warn(key)
	if stream == null:
		return

	var player := AudioStreamPlayer3D.new()
	add_child(player)

	player.stream = stream
	player.bus = sfx_bus
	player.top_level = true
	player.global_position = world_position
	player.set_meta("audio_key", key)

	active_sfx_players.append(player)
	player.finished.connect(_on_sfx_finished.bind(player))
	player.play()


func _on_sfx_finished(player: AudioStreamPlayer3D) -> void:
	if not is_instance_valid(player):
		return
	_release_sfx_player(player, false)


func _release_sfx_player(player: AudioStreamPlayer3D, stop_playback: bool) -> void:
	if stop_playback and player.playing:
		player.stop()
	active_sfx_players.erase(player)
	if is_instance_valid(player):
		player.queue_free()
