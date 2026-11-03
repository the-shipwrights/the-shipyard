@tool
extends Node

var intervall: float = 8.0
var speed: float = 5.0
var distance: float = 390.0
var width = 280.0
var angle = 0.5
var direction: Vector3 = Vector3(0.0, 0.0, 1.0).rotated(Vector3(0.0, 1.0, 0.0), angle)

var cloud_parent: Node3D
var spawn_elapsed: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cloud_parent = get_node("Clouds")
	cloud_parent.camera_height = get_node("../LanscapeCamera").size

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	spawn_elapsed += delta
	if spawn_elapsed >= intervall:
		spawn_elapsed = fmod(spawn_elapsed, intervall)
		create_cloud(Vector3(width * (randf() - 0.5), 0.0, -distance / 2.0).rotated(Vector3(0.0, 1.0, 0.0), angle))
	var i: int
	while i < cloud_parent.clouds.size():
		var cloud_distance: float = cloud_parent.clouds[i].node.position.rotated(Vector3(0.0, 1.0, 0.0), -angle).z
		if cloud_distance > distance / 2.0:
			cloud_parent.clouds[i].node.queue_free()
			cloud_parent.clouds.remove_at(i)
		else:
			i += 1
		
	cloud_parent.move_clouds(direction * speed * delta)

func create_cloud(position: Vector3):
	cloud_parent.create_cloud(
		position,
		Vector2(24.0 * (randf() / 2.0 + 0.75), 24.0) * (randf() / 2.0 + 0.75),
		12.0 + randf() * 2.0
		)
