class_name VfxEntry extends Resource

@export var key: String
@export var scene: PackedScene
@export var use_pool: bool = false
@export_range(0, 64, 1) var preload_count: int = 0
@export_range(0, 128, 1) var max_pool_size: int = 16
