@tool
extends Node

var intervall: float = 10.0
var speed: float = 5.0
var distance: float = 400.0
var width = 350.0
var angle = 0.5
var direction: Vector3 = Vector3(0.0, 0.0, 1.0).rotated(Vector3(0.0, 1.0, 0.0), angle)

var cloud_parent: Node3D
var latest_spawn: float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cloud_parent = get_node("Clouds")
	cloud_parent.camera_height = get_node("../LanscapeCamera").size
	latest_spawn = Time.get_unix_time_from_system()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Time.get_unix_time_from_system() > latest_spawn + intervall:
		create_cloud(Vector3(width * (randf() - 0.5), 0.0, -distance / 2.0).rotated(Vector3(0.0, 1.0, 0.0), angle))
		latest_spawn = Time.get_unix_time_from_system()
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
	cloud_parent.create_cloud(position, Vector2(24.0 * (randf() / 2.0 + 0.75), 24.0) * (randf() / 2.0 + 0.75), 8.0 + randf() * 2.0)
