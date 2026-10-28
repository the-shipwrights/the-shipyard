extends Node3D

@export var boat_scene: PackedScene

const BOATS_PER_ROW := 3
const SPACING_X := 5.0
const SPACING_Z := 5.0

@onready var network_manager: NetworkManager = $"../NetworkManager"

var spawned_boats: Dictionary = {}
var spawn_layout: Dictionary = {}
var row_depths: Dictionary = {}

@onready var terrain: TerrainWorld = $"../World/Terrain/TerrainWorld"

const MAP_HALF_EXTENTS := Vector2(95.0, 140.0) # X and Z half-extents
const WATER_CLEARANCE := 0.25
const ROUTE_SAMPLE_STEP := 2.0
const BOAT_GAP := 4.0

const CRUISE_SPEED := 1.0
const CRUISE_ACCELERATION := 0.8

var rng := RandomNumberGenerator.new()
var planned_routes: Dictionary = {}

func _ready() -> void:
	rng.randomize()
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
	if not is_instance_valid(boat):
		push_warning("[BoatSpawner] No spawned boat for control ID %s" % boat_id)
		return

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

	# Add the boat to the scene and build its visuals before planning its route.
	add_child(boat)
	boat.configure(boat_data)

	var route := _create_route()

	if route.is_empty():
		# Keep the boat visible even if route generation fails.
		push_warning("Could not find a clear water route for boat %s." % boat_id)
		spawned_boats[boat_id] = boat
		return

	boat.global_position = route[0]
	boat.set_route(route)

	planned_routes[boat_id] = route
	spawned_boats[boat_id] = boat
	var boat_index := spawned_boats.size()

	# Grid style
	# var row := floori(float(boat_index) / float(BOATS_PER_ROW))
	# var column := boat_index % BOATS_PER_ROW

	# add_child(boat)
	# boat.configure(boat_data)

	# var footprint: Vector3 = boat.visuals.boat_footprint

	# var position_x := 0.0
	# for existing_id in spawn_layout:
	# 	var layout: Dictionary = spawn_layout[existing_id]
	# 	if int(layout["row"]) == row:
	# 		position_x = maxf(
	# 			position_x,
	# 			float(layout["x"]) + float(layout["width"]) + SPACING_X
	# 		)

	# var position_z := 0.0
	# for previous_row in range(row):
	# 	position_z += float(row_depths.get(previous_row, 0.0)) + SPACING_Z

	# boat.position = Vector3(position_x, -0.3, position_z)

	# spawn_layout[boat_id] = {
	# 	"row": row,
	# 	"x": position_x,
	# 	"width": footprint.x,
	# }
	# row_depths[row] = maxf(
	# 	float(row_depths.get(row, 0.0)),
	# 	footprint.z
	# )

	if route.is_empty():
		boat.queue_free()
		push_warning("Could not find a clear water route for boat %s." % boat_id)
		return

	boat.position = route[0]
	boat.set_route(route)
	planned_routes[boat_id] = route
	spawned_boats[boat_id] = boat

	spawned_boats[boat_id] = boat

func _create_route() -> Array[Vector3]:
	for _attempt in range(30):
		var start := _random_water_point()
		if start == Vector3.INF:
			continue

		var route: Array[Vector3] = [start]
		var valid := true

		for _waypoint in range(5):
			var found := false

			for _candidate_attempt in range(80):
				var candidate := _random_water_point()
				if candidate == Vector3.INF:
					continue

				if _segment_is_clear(route[-1], candidate):
					route.append(candidate)
					found = true
					break

			if not found:
				valid = false
				break

		if valid and _segment_is_clear(route[-1], route[0]):
			return route

	return []


func _random_water_point() -> Vector3:
	for _attempt in range(100):
		var point := Vector3(
			rng.randf_range(-MAP_HALF_EXTENTS.x, MAP_HALF_EXTENTS.y),
			0.15,
			rng.randf_range(-MAP_HALF_EXTENTS.x, MAP_HALF_EXTENTS.y)
		)

		if _is_deep_water(point) and _is_clear_of_planned_routes(point):
			return point

	return Vector3.INF


func _is_deep_water(world_point: Vector3) -> bool:
	var local_point := terrain.to_local(world_point)
	var ground_height := terrain.sample_height_local(
		local_point.x,
		local_point.z
	)
	return ground_height < terrain.sea_level - WATER_CLEARANCE


func _segment_is_clear(a: Vector3, b: Vector3) -> bool:
	var distance := a.distance_to(b)
	var sample_count := maxi(1, ceili(distance / ROUTE_SAMPLE_STEP))

	for i in range(sample_count + 1):
		var point := a.lerp(b, float(i) / float(sample_count))

		if not _is_deep_water(point):
			return false
		if not _is_clear_of_planned_routes(point):
			return false

	return true


func _is_clear_of_planned_routes(point: Vector3) -> bool:
	for route_variant in planned_routes.values():
		var route: Array = route_variant

		for i in range(route.size()):
			var a: Vector3 = route[i]
			var b: Vector3 = route[(i + 1) % route.size()]

			if _distance_to_segment(point, a, b) < BOAT_GAP:
				return false

	return true


func _distance_to_segment(
	point: Vector3,
	a: Vector3,
	b: Vector3
) -> float:
	var segment := b - a
	var length_squared := segment.length_squared()

	if length_squared == 0.0:
		return point.distance_to(a)

	var t := clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(a + t * segment)
