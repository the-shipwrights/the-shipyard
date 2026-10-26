@tool

extends Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in range($CloudMesh.multimesh.instance_count):
		var transform = Transform3D()
		transform = transform.translated(Vector3(randf() * 5, 0.0, randf() * 5))
		transform = transform.scaled(Vector3(1.0, 1.0, 1.0))
		$CloudMesh.multimesh.set_instance_transform(i, transform)
