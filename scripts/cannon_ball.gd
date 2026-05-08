class_name CannonBall extends RigidBody3D

@export var max_lifetime: float = 5.0

func _ready() -> void:
	pass # Replace with function body.


func _process(delta: float) -> void:
	max_lifetime -= delta
	if max_lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	print("Bullet hit: ", body.name)
	
	var ship: Ship = body as Ship
	ship.take_hit()
	
	queue_free()
