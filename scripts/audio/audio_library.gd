class_name AudioLibrary extends Resource

@export_range(0, 64, 1) var sfx_preload_count: int = 4
@export_range(0, 128, 1) var max_sfx_pool_size: int = 32
@export var entries: Array[AudioEntry]
