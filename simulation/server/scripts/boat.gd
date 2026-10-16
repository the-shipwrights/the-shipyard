extends Node3D
class_name Boat

const ROTATION_SPEED := 1.8

@onready var visuals: MeshConstructor = $MeshConstructor
@onready var id_label: Label3D = $IDLabel

var boat_id := ""
var rotation_active := false


func configure(data: Dictionary) -> void:
	boat_id = str(data.get("id", ""))
	id_label.text = boat_id
	visuals.build_from_data(data)


func apply_control(command: String, active: bool) -> void:
	if command == "rotate":
		rotation_active = active


func _process(delta: float) -> void:
	if rotation_active:
		rotate_y(ROTATION_SPEED * delta)
