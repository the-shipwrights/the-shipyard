@tool
extends MeshInstance3D
class_name WaterSurface

## Attach to the water MeshInstance3D (the one using water.gdshader).
## Reads the terrain's public data, so the terrain script stays untouched.

@export var terrain: TerrainWorld
@export var max_dist := 40.0 ## distances beyond this are treated as open ocean
@export var height_blur_passes := 1     ## smooths depth/coastline fed to the water
@export var distance_blur_passes := 3   ## smooths the shore-distance field

func _blur(src: PackedFloat32Array, width: int, depth: int, passes: int) -> PackedFloat32Array:
	var a := src.duplicate()
	var b := src.duplicate()
	for _pass in range(passes):
		for z in range(depth):
			for x in range(width):
				var sum := 0.0
				var count := 0.0
				for dz in range(-1, 2):
					var sample_z := z + dz
					if sample_z < 0 or sample_z >= depth:
						continue
					for dx in range(-1, 2):
						var sample_x := x + dx
						if sample_x < 0 or sample_x >= width:
							continue
						sum += a[sample_z * width + sample_x]
						count += 1.0
				b[z * width + x] = sum / count
		var temp := a
		a = b
		b = temp
	return a

func _ready() -> void:
	# Let the terrain finish generating its heights in its own _ready().
	await get_tree().process_frame
	_push_params()


func _push_params() -> void:
	var mat := get_active_material(0) as ShaderMaterial
	if terrain == null or mat == null:
		push_warning("WaterSurface: missing terrain or ShaderMaterial")
		return
	if terrain.heights.is_empty():
		push_warning("WaterSurface: terrain heights are empty")
		return

	var width := terrain.width
	var depth := terrain.depth
	if terrain.heights.size() != width * depth:
		push_warning("WaterSurface: terrain height count does not match width × depth")
		return

	var half_width := float(width - 1) * terrain.CELL_SIZE * 0.5
	var half_depth := float(depth - 1) * terrain.CELL_SIZE * 0.5

	var smooth_heights := _blur(terrain.heights, width, depth, height_blur_passes)
	var smooth_shore_distance := _blur(_distance_field(smooth_heights, width, depth), width, depth, distance_blur_passes)

	var height_image := Image.create_from_data(width, depth, false, Image.FORMAT_RF, smooth_heights.to_byte_array())
	var shore_image := Image.create_from_data(width, depth, false, Image.FORMAT_RF, smooth_shore_distance.to_byte_array())

	mat.set_shader_parameter("terrain_height", ImageTexture.create_from_image(height_image))
	mat.set_shader_parameter("shore_dist", ImageTexture.create_from_image(shore_image))
	mat.set_shader_parameter("terrain_origin",
		Vector2(terrain.global_position.x - half_width, terrain.global_position.z - half_depth))
	mat.set_shader_parameter("cell_size", terrain.CELL_SIZE)
	mat.set_shader_parameter("terrain_size", Vector2(width, depth))
	mat.set_shader_parameter("sea_level", terrain.sea_level)
	mat.set_shader_parameter("ocean_depth_m", terrain.ocean_depth_m)
	mat.set_shader_parameter("shore_max_dist", max_dist)


## Distance in meters from each cell to the nearest land cell.
## Uses a two-pass chamfer distance transform.
func _distance_field(heights: PackedFloat32Array, width: int, depth: int) -> PackedFloat32Array:
	var distances := PackedFloat32Array()
	distances.resize(width * depth)
	for index in range(width * depth):
		distances[index] = 0.0 if heights[index] >= terrain.sea_level else 1.0e9

	var orthogonal_cost := 0.9604
	var diagonal_cost := 1.3693

	# Forward pass.
	for z in range(depth):
		for x in range(width):
			var index := z * width + x
			var value := distances[index]
			if x > 0:
				value = minf(value, distances[index - 1] + orthogonal_cost)
			if z > 0:
				value = minf(value, distances[index - width] + orthogonal_cost)
				if x > 0:
					value = minf(value, distances[index - width - 1] + diagonal_cost)
				if x < width - 1:
					value = minf(value, distances[index - width + 1] + diagonal_cost
					)

			distances[index] = value

	# Backward pass.
	for z in range(depth - 1, -1, -1):
		for x in range(width - 1, -1, -1):
			var index := z * width + x
			var value := distances[index]

			if x < width - 1:
				value = minf(value, distances[index + 1] + orthogonal_cost)
			if z < depth - 1:
				value = minf(
					value,
					distances[index + width] + orthogonal_cost
				)

				if x < width - 1:
					value = minf(value, distances[index + width + 1] + diagonal_cost
					)
				if x > 0:
					value = minf(
						value,
						distances[index + width - 1] + diagonal_cost
					)

			distances[index] = value

	for index in range(width * depth):
		distances[index] = minf(
			distances[index] * terrain.CELL_SIZE,
			max_dist
		)

	return distances
