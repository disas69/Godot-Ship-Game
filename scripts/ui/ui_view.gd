class_name UiView extends CanvasLayer

var view_id := ""


func open() -> void:
	visible = true


func close() -> void:
	queue_free()
