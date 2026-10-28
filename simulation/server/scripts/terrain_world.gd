@tool

extends Node3D
class_name TerrainWorld

# TODO: Terrain bounding box should not depend on Cell size. Width and depth should specify
# Terrain size in metric units rather than the number of cells.

var _width := 257
## Number of height samples along the X axis.
@export_range(3, 1025, 2) var width: int:
	get:
		return _width
	set(value):
		_width = _adjust_sample_count(value)
		_request_terrain_regeneration()


var _depth := 257
## Number of height samples along the Z axis.
@export_range(3, 1025, 2) var depth: int:
	get:
		return _depth
	set(value):
		_depth = _adjust_sample_count(value)
		_request_terrain_regeneration()


var _terrain_seed := 2026
## TODO: Documentation
@export var terrain_seed: int:
	get:
		return _terrain_seed
	set(value):
		_terrain_seed = value
		_request_terrain_regeneration()


var _sea_level := 0.0
## TODO: Documentation
@export var sea_level: float:
	get:
		return _sea_level
	set(value):
		_sea_level = value
		_request_terrain_regeneration()


var _ocean_depth_m := 5.0
## TODO: Documentation
@export var ocean_depth_m: float:
	get:
		return _ocean_depth_m
	set(value):
		_ocean_depth_m = maxf(value, 0.0)
		_request_terrain_regeneration()


var _cell_size := 1.0
## TODO: Documentation
@export var CELL_SIZE: float:
	get:
		return _cell_size
	set(value):
		_cell_size = maxf(value, 0.001)
		_request_terrain_regeneration()


@export_group("Landscape settings")

var _ocean_to_land_ratio := 6.0
## TODO: Documentation
@export_range(1, 20.0, 0.1) var ocean_to_land_ratio: float:
	get:
		return _ocean_to_land_ratio
	set(value):
		_ocean_to_land_ratio = clampf(value, 0.1, 20.0)
		_request_terrain_regeneration()


var _minimum_channel_width_m := 2.0
## TODO: Documentation
@export_range(2.0, 20.0, 0.5) var minimum_channel_width_m: float:
	get:
		return _minimum_channel_width_m
	set(value):
		_minimum_channel_width_m = clampf(value, 2.0, 20.0)
		_request_terrain_regeneration()


var _coast_shelf_width_m := 12.0
## TODO: Documentation
@export_range(2.0, 40.0, 0.5) var coast_shelf_width_m: float:
	get:
		return _coast_shelf_width_m
	set(value):
		_coast_shelf_width_m = clampf(value, 2.0, 40.0)
		_request_terrain_regeneration()


var _island_scale_m := 60
## TODO: Documentation
@export_range(16.0, 120.0, 1.0) var island_scale_m: float:
	get:
		return _island_scale_m
	set(value):
		_island_scale_m = clampf(value, 16.0, 120.0)
		_request_terrain_regeneration()


var _mountain_scale_m := 40
## TODO: Documentation
@export_range(8.0, 100.0, 1.0) var mountain_scale_m: float:
	get:
		return _mountain_scale_m
	set(value):
		_mountain_scale_m = clampf(value, 8.0, 100.0)
		_request_terrain_regeneration()

var _mountain_height_m := 30.0
## TODO: Documentation
@export_range(0.0, 60.0, 0.5) var mountain_height_m: float:
	get:
		return _mountain_height_m
	set(value):
		_mountain_height_m = maxf(value, 0.0)
		if is_node_ready():
			call_deferred("_regenerate_terrain")

# NITPICK: these should be @exports. implementing node hierarchies in this fashion makes
# this node less modular, as it requires a specific configuration of child nodes to work.
# we can let this pass due to deadline.
@onready var terrain_mesh: MeshInstance3D = $TerrainMesh
@onready var collision_shape: CollisionShape3D = $TerrainBody/CollisionShape3D

var heights := PackedFloat32Array()
var _regeneration_queued := false


func _adjust_sample_count(value: int) -> int:
	var adjusted := clampi(value, 3, 1025)
	if adjusted % 2 == 0:
		adjusted = mini(adjusted + 1, 1025)
	return adjusted


func _request_terrain_regeneration() -> void:
	if not is_node_ready() or _regeneration_queued:
		return

	_regeneration_queued = true
	call_deferred("_run_queued_terrain_regeneration")

func _run_queued_terrain_regeneration() -> void:
	_regeneration_queued = false
	_regenerate_terrain()

func _ready() -> void:
	_regenerate_terrain()

# NITPICK: Consider moving TerrainGenerator to a child Node of TerrainWorld.
# Nodes are much more traceable than script chains, and the engine overhead for this operation is negligible.
func _regenerate_terrain() -> void:
	var generator := TerrainGenerator.new()
	generator.configure(
		terrain_seed,
		ocean_to_land_ratio,
		minimum_channel_width_m,
		coast_shelf_width_m,
		sea_level,
		ocean_depth_m,
		island_scale_m,
		mountain_scale_m,
		mountain_height_m
	)
	heights = generator.build_heights(width, depth, CELL_SIZE)
	_build_mesh()
	_build_collision()


func _vertex_at(x: int, z: int) -> Vector3:
	var half_width := float(width - 1) * CELL_SIZE * 0.5
	var half_depth := float(depth - 1) * CELL_SIZE * 0.5
	var height_index := z * width + x

	return Vector3(
		x * CELL_SIZE - half_width,
		heights[height_index],
		z * CELL_SIZE - half_depth
	)


func _build_mesh() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z in range(depth - 1):
		for x in range(width - 1):
			var p00 := _vertex_at(x, z)
			var p10 := _vertex_at(x + 1, z)
			var p01 := _vertex_at(x, z + 1)
			var p11 := _vertex_at(x + 1, z + 1)

			# Clockwise winding as viewed from above
			surface.add_vertex(p00)
			surface.add_vertex(p10)
			surface.add_vertex(p01)

			surface.add_vertex(p01)
			surface.add_vertex(p10)
			surface.add_vertex(p11)

	surface.generate_normals(true)
	terrain_mesh.mesh = surface.commit()


func _build_collision() -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = width
	shape.map_depth = depth
	shape.map_data = heights
	collision_shape.shape = shape


func sample_height_local(local_x: float, local_z: float) -> float:
	var half_width := float(width - 1) * CELL_SIZE * 0.5
	var half_depth := float(depth - 1) * CELL_SIZE * 0.5
	var grid_x := (local_x + half_width) / CELL_SIZE
	var grid_z := (local_z + half_depth) / CELL_SIZE

	if grid_x < 0.0 or grid_z < 0.0:
		return sea_level - ocean_depth_m
	if grid_x > width - 1 or grid_z > depth - 1:
		return sea_level - ocean_depth_m

	var x0 := floori(grid_x)
	var z0 := floori(grid_z)
	var x1 := mini(x0 + 1, width - 1)
	var z1 := mini(z0 + 1, depth - 1)
	var tx := grid_x - x0
	var tz := grid_z - z0

	var h00 := heights[z0 * width + x0]
	var h10 := heights[z0 * width + x1]
	var h01 := heights[z1 * width + x0]
	var h11 := heights[z1 * width + x1]

	var top := lerpf(h00, h10, tx)
	var bottom := lerpf(h01, h11, tx)
	return lerpf(top, bottom, tz)


func sample_water_depth_local(local_x: float, local_z: float) -> float:
	return maxf(0.0, sea_level - sample_height_local(local_x, local_z))
