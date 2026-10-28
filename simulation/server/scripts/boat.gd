extends Node3D
class_name Boat

const ROTATION_SPEED := 1.8

@onready var visuals: MeshConstructor = $MeshConstructor
@onready var id_label: Label3D = $IDLabel
@onready var trail: MeshInstance3D = $PretendTrail

var boat_id := ""
var rotation_active := false

const MAX_SPEED := 5.0
const ACCELERATION := 1.5
const COAST_DECELERATION := 0.8
const TURN_RATE := 1.2
const WAYPOINT_REACHED_DISTANCE := 1.5

const CRUISE_SPEED := 1.0
const CRUISE_ACCELERATION := 0.8

var route: Array[Vector3] = []
var waypoint_index := 1
var throttle_active := false
var current_speed := 0.0


func configure(data: Dictionary) -> void:
	boat_id = str(data.get("id", ""))
	id_label.text = boat_id
	visuals.build_from_data(data)
	visuals.rotation.y = deg_to_rad(90.0)

func apply_control(command: String, active: bool) -> void:
	if command == "rotate":
		rotation_active = active
	if command == "accelerate":
		throttle_active = active
		trail.show()


func _process(delta: float) -> void:
	if rotation_active:
		rotate_y(ROTATION_SPEED * delta)
	
	if route.size() < 2:
		return
	
	if not throttle_active:
		trail.hide()
	
	var target := route[waypoint_index]
	var to_target := target - global_position
	to_target.y = 0.0

	if to_target.length() < WAYPOINT_REACHED_DISTANCE:
		waypoint_index = (waypoint_index + 1) % route.size()
		target = route[waypoint_index]
		to_target = target - global_position
		to_target.y = 0.0

	var desired_yaw := atan2(-to_target.x, -to_target.z)
	rotation.y = lerp_angle(
		rotation.y,
		desired_yaw,
		minf(1.0, TURN_RATE * delta)
	)

	var target_speed := MAX_SPEED if throttle_active else CRUISE_SPEED
	var rate := ACCELERATION if throttle_active else CRUISE_ACCELERATION

	current_speed = move_toward(current_speed, target_speed, rate * delta)

	global_position += -global_basis.z * current_speed * delta

func set_route(new_route: Array[Vector3]) -> void:
	route = new_route
	waypoint_index = 1
