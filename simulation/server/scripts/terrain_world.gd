@tool

extends Node3D
class_name TerrainWorld

@export_range(3, 1025, 2) var resolution := 101
@export var terrain_seed := 2026
@export var sea_level := 0.0
@export var ocean_depth_m := 5.0
@export var CELL_SIZE := 1.0

@export_group("Landscape settings")

@export_range(0.1, 20.0, 0.1) var ocean_to_land_ratio := 4.0
@export_range(2.0, 20.0, 0.5) var minimum_channel_width_m := 2.0
@export_range(16.0, 120.0, 1.0) var island_scale_m := 18.0
@export_range(8.0, 100.0, 1.0) var mountain_scale_m := 14.0
@export_range(0.0, 60.0, 0.5) var mountain_height_m := 5.0


@onready var terrain_mesh: MeshInstance3D = $TerrainMesh
@onready var collision_shape: CollisionShape3D = $TerrainBody/CollisionShape3D

var heights := PackedFloat32Array()


func _ready() -> void:
	var generator := TerrainGenerator.new()
	generator.configure(
		terrain_seed,
		ocean_to_land_ratio,
		minimum_channel_width_m,
		sea_level,
		ocean_depth_m,
		island_scale_m,
		mountain_scale_m,
		mountain_height_m
	)

	heights = generator.build_heights(resolution, CELL_SIZE)
	_build_mesh()
	_build_collision()


func _vertex_at(x: int, z: int) -> Vector3:
	var half_extent := (resolution - 1) * CELL_SIZE * 0.5
	var height_index := z * resolution + x

	return Vector3(
		x * CELL_SIZE - half_extent,
		heights[height_index],
		z * CELL_SIZE - half_extent
	)


func _build_mesh() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z in range(resolution - 1):
		for x in range(resolution - 1):
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
	shape.map_width = resolution
	shape.map_depth = resolution
	shape.map_data = heights
	collision_shape.shape = shape


func sample_height_local(local_x: float, local_z: float) -> float:
	var half_extent := (resolution - 1) * CELL_SIZE * 0.5
	var grid_x := (local_x + half_extent) / CELL_SIZE
	var grid_z := (local_z + half_extent) / CELL_SIZE

	if grid_x < 0.0 or grid_z < 0.0:
		return sea_level - ocean_depth_m
	if grid_x > resolution - 1 or grid_z > resolution - 1:
		return sea_level - ocean_depth_m

	var x0 := floori(grid_x)
	var z0 := floori(grid_z)
	var x1 := mini(x0 + 1, resolution - 1)
	var z1 := mini(z0 + 1, resolution - 1)
	var tx := grid_x - x0
	var tz := grid_z - z0

	var h00 := heights[z0 * resolution + x0]
	var h10 := heights[z0 * resolution + x1]
	var h01 := heights[z1 * resolution + x0]
	var h11 := heights[z1 * resolution + x1]

	var top := lerpf(h00, h10, tx)
	var bottom := lerpf(h01, h11, tx)
	return lerpf(top, bottom, tz)


func sample_water_depth_local(local_x: float, local_z: float) -> float:
	return maxf(0.0, sea_level - sample_height_local(local_x, local_z))
