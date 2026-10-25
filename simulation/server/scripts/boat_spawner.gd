extends Node3D

@export var boat_scene: PackedScene

const BOATS_PER_ROW := 3
const SPACING_X := 5.0
const SPACING_Z := 5.0

@onready var network_manager: NetworkManager = $"../NetworkManager"

var spawned_boats: Dictionary = {}
var spawn_layout: Dictionary = {}
var row_depths: Dictionary = {}

func _ready() -> void:
	network_manager.initial_boats_received.connect(_on_initial_boats_received)
	network_manager.boat_launched.connect(_on_boat_launched)
	network_manager.boat_control_received.connect(_on_boat_control_received)

func _on_initial_boats_received(boats: Array) -> void:
	for boat_data in boats:
		if boat_data is Dictionary:
			_spawn_or_update_boat(boat_data)


func _on_boat_launched(boat_data: Dictionary) -> void:
	_spawn_or_update_boat(boat_data)


func _on_boat_control_received(
	boat_id: String,
	command: String,
	active: bool
) -> void:
	var boat := spawned_boats.get(boat_id) as Boat
	if is_instance_valid(boat):
		boat.apply_control(command, active)


func _spawn_or_update_boat(boat_data: Dictionary) -> void:
	var boat_id := str(boat_data.get("id", ""))
	if boat_id.is_empty():
		return

	if spawned_boats.has(boat_id):
		var existing_boat := spawned_boats[boat_id] as Boat
		if is_instance_valid(existing_boat):
			existing_boat.configure(boat_data)
		return

	# In the spawn path:
	var boat := boat_scene.instantiate() as Boat
	if boat == null:
		push_error("Boat scene must have a Boat root.")
		return

	var boat_index := spawned_boats.size()
	var row := floori(float(boat_index) / float(BOATS_PER_ROW))
	var column := boat_index % BOATS_PER_ROW

	add_child(boat)
	boat.configure(boat_data)

	var footprint: Vector3 = boat.visuals.boat_footprint

	var position_x := 0.0
	for existing_id in spawn_layout:
		var layout: Dictionary = spawn_layout[existing_id]
		if int(layout["row"]) == row:
			position_x = maxf(
				position_x,
				float(layout["x"]) + float(layout["width"]) + SPACING_X
			)

	var position_z := 0.0
	for previous_row in range(row):
		position_z += float(row_depths.get(previous_row, 0.0)) + SPACING_Z

	boat.position = Vector3(position_x, 0.0, position_z)

	spawn_layout[boat_id] = {
		"row": row,
		"x": position_x,
		"width": footprint.x,
	}
	row_depths[row] = maxf(
		float(row_depths.get(row, 0.0)),
		footprint.z
	)

	spawned_boats[boat_id] = boat
