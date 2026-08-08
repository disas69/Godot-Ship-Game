class_name AudioEntry extends Resource

@export var key: String
@export var stream: AudioStream
@export_range(-80.0, 24.0, 0.1, "suffix:dB") var volume: float = 0.0
@export_range(0.01, 100.0, 0.01, "or_greater") var unit_size: float = 10.0
@export_range(0.01, 4.0, 0.01, "or_greater") var pitch_scale: float = 1.0
@export_range(0.0, 4096.0, 0.1, "or_greater", "suffix:m") var max_distance: float = 0.0
@export_range(1, 16, 1) var max_polyphony: int = 3
@export_range(0.0, 0.5, 0.01) var pitch_randomness: float = 0.06
@export_range(0.0, 0.5, 0.01) var min_interval_sec: float = 0.04

