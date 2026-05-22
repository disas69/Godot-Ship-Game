extends Node

@export var library: VfxLibrary = preload("res://vfx/vfx_library.tres")

var vfx_map: Dictionary[StringName, VfxEntry] = {}
var active_effects: Dictionary[Node3D, VfxEntry] = {}
var pools: Dictionary[StringName, ObjectPool] = {}
var pool_root: Node3D


func _ready() -> void:
	ensure_pool_root()
	rebuild_vfx_map()
	prewarm_pools()


func spawn(key: String, world_position: Vector3 = Vector3.ZERO) -> Node3D:
	var transform := Transform3D(Basis(), world_position)
	return spawn_at_transform(key, transform)


func spawn_at_transform(key: String, global_transform: Transform3D, parent: Node = null) -> Node3D:
	var entry := get_entry_or_warn(key)
	if entry == null:
		return null

	var effect := get_effect_instance(entry)
	if effect == null:
		return null

	move_effect_to_parent(effect, get_spawn_parent(parent))
	effect.global_transform = global_transform
	prepare_effect_for_spawn(effect, entry)
	start_effect(effect)
	return effect


func spawn_attached(key: String, parent: Node3D, local_transform: Transform3D = Transform3D.IDENTITY) -> Node3D:
	if parent == null:
		push_warning("Cannot spawn VFX '%s' because parent is null." % key)
		return null

	var entry := get_entry_or_warn(key)
	if entry == null:
		return null

	var effect := get_effect_instance(entry)
	if effect == null:
		return null

	move_effect_to_parent(effect, parent)
	effect.transform = local_transform
	prepare_effect_for_spawn(effect, entry)
	start_effect(effect)
	return effect


func stop(effect: Node3D) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	release_effect(effect)


func stop_key(key: String) -> void:
	var effects := active_effects.keys()
	for effect in effects:
		if not is_instance_valid(effect):
			continue
		var entry := active_effects.get(effect) as VfxEntry
		if entry != null and entry.key == key:
			release_effect(effect)


func clear() -> void:
	var effects := active_effects.keys()
	for effect in effects:
		if is_instance_valid(effect):
			effect.queue_free()
	active_effects.clear()

	for pool in pools.values():
		pool.clear()
	pools.clear()


func ensure_pool_root() -> void:
	if pool_root != null and is_instance_valid(pool_root):
		return

	pool_root = Node3D.new()
	pool_root.name = "VfxPool"
	pool_root.visible = false
	add_child(pool_root)


func rebuild_vfx_map() -> void:
	vfx_map.clear()
	if library == null:
		push_warning("VFX library is not assigned.")
		return

	for entry in library.entries:
		if entry == null:
			continue
		if entry.key.is_empty():
			continue
		if entry.scene == null:
			push_warning("VFX entry '%s' has no scene assigned." % entry.key)
			continue

		vfx_map[StringName(entry.key)] = entry
		if not pools.has(StringName(entry.key)):
			pools[StringName(entry.key)] = create_effect_pool(entry)


func prewarm_pools() -> void:
	for entry in vfx_map.values():
		if not entry.use_pool:
			continue

		var pool := pools[StringName(entry.key)]
		pool.prewarm(entry.preload_count)


func get_entry_or_warn(key: String) -> VfxEntry:
	var entry := vfx_map.get(StringName(key)) as VfxEntry
	if entry == null:
		push_warning("Missing VFX key: " + key)
	return entry


func get_effect_instance(entry: VfxEntry) -> Node3D:
	if entry.use_pool:
		var pool := pools[StringName(entry.key)]
		var effect := pool.acquire() as Node3D
		if effect != null:
			return effect

	return instantiate_effect(entry)


func instantiate_effect(entry: VfxEntry) -> Node3D:
	var effect := entry.scene.instantiate() as Node3D
	if effect == null:
		push_warning("VFX entry '%s' scene root must be a Node3D." % entry.key)
		return null

	if effect is VfxAnimationPlayer:
		var animation_effect := effect as VfxAnimationPlayer
		animation_effect.auto_play = false
		animation_effect.free_on_finished = false
	elif effect is VfxPlayer:
		var particle_effect := effect as VfxPlayer
		particle_effect.auto_play = false
		particle_effect.free_on_finished = false

	effect.tree_exiting.connect(on_effect_tree_exiting.bind(effect))
	return effect


func prepare_effect_for_spawn(effect: Node3D, entry: VfxEntry) -> void:
	active_effects[effect] = entry
	effect.visible = true
	effect.process_mode = Node.PROCESS_MODE_INHERIT
	effect.set_meta("vfx_key", entry.key)

	if effect is VfxAnimationPlayer:
		var animation_effect := effect as VfxAnimationPlayer
		animation_effect.free_on_finished = false
		if not animation_effect.finished.is_connected(on_effect_finished):
			animation_effect.finished.connect(on_effect_finished)
	elif effect is VfxPlayer:
		var particle_effect := effect as VfxPlayer
		particle_effect.free_on_finished = false
		if not particle_effect.finished.is_connected(on_effect_finished):
			particle_effect.finished.connect(on_effect_finished)


func start_effect(effect: Node3D) -> void:
	if effect is VfxAnimationPlayer:
		(effect as VfxAnimationPlayer).play()
	elif effect is VfxPlayer:
		(effect as VfxPlayer).play()
	else:
		restart_particles(effect)


func release_effect(effect: Node3D) -> void:
	var entry := active_effects.get(effect) as VfxEntry
	if entry == null:
		return

	active_effects.erase(effect)
	if effect is VfxAnimationPlayer:
		var animation_effect := effect as VfxAnimationPlayer
		if animation_effect.finished.is_connected(on_effect_finished):
			animation_effect.finished.disconnect(on_effect_finished)
		animation_effect.reset_for_pool()
	elif effect is VfxPlayer:
		var particle_effect := effect as VfxPlayer
		if particle_effect.finished.is_connected(on_effect_finished):
			particle_effect.finished.disconnect(on_effect_finished)
		particle_effect.reset_for_pool()

	if entry.use_pool:
		return_to_pool(effect, entry)
	else:
		effect.queue_free()


func return_to_pool(effect: Node3D, entry: VfxEntry) -> void:
	var pool := pools[StringName(entry.key)]
	pool.release(effect)


func create_effect_pool(entry: VfxEntry) -> ObjectPool:
	return ObjectPool.new(
		instantiate_effect.bind(entry),
		reset_effect_for_pool.bind(entry),
		discard_effect,
		entry.max_pool_size
	)


func reset_effect_for_pool(effect: Node3D, _entry: VfxEntry) -> void:
	reset_effect_state(effect)

	if effect.get_parent() != pool_root:
		if effect.get_parent() != null:
			effect.get_parent().remove_child(effect)
		pool_root.add_child(effect)

	effect.visible = false
	effect.process_mode = Node.PROCESS_MODE_DISABLED


func reset_effect_state(effect: Node3D) -> void:
	if effect is VfxAnimationPlayer:
		(effect as VfxAnimationPlayer).reset_for_pool()
	elif effect is VfxPlayer:
		(effect as VfxPlayer).reset_for_pool()
	else:
		stop_particles(effect)


func discard_effect(effect: Node3D) -> void:
	if is_instance_valid(effect):
		effect.queue_free()


func move_effect_to_parent(effect: Node3D, parent: Node) -> void:
	if effect.get_parent() == parent:
		return
	if effect.get_parent() != null:
		effect.get_parent().remove_child(effect)
	parent.add_child(effect)


func get_spawn_parent(parent: Node) -> Node:
	if parent != null:
		return parent
	if get_tree().current_scene != null:
		return get_tree().current_scene
	return get_tree().root


func restart_particles(root: Node) -> void:
	if root is GPUParticles3D:
		var root_particles := root as GPUParticles3D
		root_particles.emitting = false
		root_particles.restart()
		root_particles.emitting = true

	for child in root.find_children("*", "GPUParticles3D", true, false):
		var particles := child as GPUParticles3D
		particles.emitting = false
		particles.restart()
		particles.emitting = true


func stop_particles(root: Node) -> void:
	if root is GPUParticles3D:
		var root_particles := root as GPUParticles3D
		root_particles.emitting = false
		root_particles.restart()
		root_particles.emitting = false

	for child in root.find_children("*", "GPUParticles3D", true, false):
		var particles := child as GPUParticles3D
		particles.emitting = false
		particles.restart()
		particles.emitting = false


func on_effect_finished(effect: Node3D) -> void:
	if not is_instance_valid(effect):
		return
	release_effect(effect)


func on_effect_tree_exiting(effect: Node3D) -> void:
	active_effects.erase(effect)
