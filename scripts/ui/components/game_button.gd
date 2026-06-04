class_name GameButton extends UiTweenButton

@export var label: String = "Button":
	set(value):
		label = value
		text = value


func _ready() -> void:
	text = label
	silent = true
	super._ready()
