@tool
extends RefCounted
class_name TerrainGenerator

var seed := 2026
var ocean_to_land_ratio := 6.0
var minimum_channel_width_m := 5.0
var sea_level := 0.0
var ocean_depth_m := 10.0
var island_scale_m := 38.0
var mountain_scale_m := 28.0
var mountain_height_m := 24.0

var base_relief_m := 8.0
var relief_amplitude_m := 1.5
var max_land_height_m := 40.0
var mountain_sharpness := 1.7

var _land_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _warp_noise: FastNoiseLite
var _height_noise: FastNoiseLite
var _mountain_noise: FastNoiseLite

var _land_fields := PackedFloat32Array()
var _water_mask := PackedByteArray()
var _land_threshold := 0.0
var _land_field_max := 1.0


func configure(
	world_seed: int,
	world_ocean_to_land_ratio: float,
	channel_width_m: float,
	world_sea_level: float,
	world_ocean_depth_m: float,
	world_island_scale_m: float,
	world_mountain_scale_m: float,
	world_mountain_height_m: float
) -> void:
	seed = world_seed
	ocean_to_land_ratio = maxf(world_ocean_to_land_ratio, 0.01)
	minimum_channel_width_m = maxf(channel_width_m, 0.0)
	sea_level = world_sea_level
	ocean_depth_m = maxf(world_ocean_depth_m, 0.1)
	island_scale_m = maxf(world_island_scale_m, 1.0)
	mountain_scale_m = maxf(world_mountain_scale_m, 1.0)
	mountain_height_m = maxf(world_mountain_height_m, 0.0)

	_land_noise = _make_noise(seed, 1.0 / island_scale_m, 3, FastNoiseLite.FRACTAL_FBM)

	_detail_noise = _make_noise(seed + 1, 2.0 / island_scale_m, 1, FastNoiseLite.FRACTAL_FBM)

	_warp_noise = _make_noise(seed + 2, 1.0 / island_scale_m, 2, FastNoiseLite.FRACTAL_FBM)

	_height_noise = _make_noise(seed + 3, 1.0 / 100.0, 2, FastNoiseLite.FRACTAL_FBM)

	_mountain_noise = _make_noise(seed + 4, 1.0 / mountain_scale_m, 3, FastNoiseLite.FRACTAL_RIDGED)



func _make_noise(
	noise_seed: int,
	noise_frequency: float,
	octaves: int,
	fractal_mode: int
) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_frequency
	noise.fractal_type = fractal_mode
	noise.fractal_octaves = octaves
	return noise


func _land_signal_at(x: float, z: float) -> float:
	var warp_strength := island_scale_m * 0.08
	var warp_x := _warp_noise.get_noise_2d(x, z) * warp_strength
	var warp_z := _warp_noise.get_noise_2d(x + 731.0, z - 419.0) * warp_strength

	var broad_shape := _land_noise.get_noise_2d(x + warp_x, z + warp_z)
	var small_coast_detail := _detail_noise.get_noise_2d(x, z)

	return broad_shape * 0.94 + small_coast_detail * 0.06


func build_heights(resolution: int, cell_size: float) -> PackedFloat32Array:
	var point_count := resolution * resolution
	var half_extent := float(resolution - 1) * cell_size * 0.5

	_land_fields.resize(point_count)
	_land_field_max = -INF

	for z in range(resolution):
		for x in range(resolution):
			var local_x := float(x) * cell_size - half_extent
			var local_z := float(z) * cell_size - half_extent
			var index := z * resolution + x
			var land_signal := _land_signal_at(local_x, local_z)

			_land_fields[index] = land_signal
			_land_field_max = maxf(_land_field_max, land_signal)

	_water_mask = _find_water_mask(resolution, cell_size)

	var heights := PackedFloat32Array()
	heights.resize(point_count)

	for z in range(resolution):
		for x in range(resolution):
			var local_x := float(x) * cell_size - half_extent
			var local_z := float(z) * cell_size - half_extent
			var index := z * resolution + x

			if _water_mask[index] != 0:
				heights[index] = sea_level - ocean_depth_m
				continue

			var inland := clampf(
				(_land_fields[index] - _land_threshold)
					/ maxf(0.001, _land_field_max - _land_threshold),
				0.0,
				1.0
			)

			var broad_relief := (
				_height_noise.get_noise_2d(local_x, local_z)
				* relief_amplitude_m
			)
			var ridge_sample := _mountain_noise.get_noise_2d(local_x, local_z)
			var ridge := clampf((ridge_sample + 1.0) * 0.5, 0.0, 1.0)
			var mountain_relief := pow(ridge, mountain_sharpness) * mountain_height_m

			var land_height := (
				sea_level
				+ 0.5
				+ inland * (base_relief_m + broad_relief + mountain_relief)
			)

			heights[index] = clampf(
				land_height,
				sea_level + 0.25,
				sea_level + max_land_height_m
			)

	return heights


func _find_water_mask(resolution: int, cell_size: float) -> PackedByteArray:
	var target_ocean_fraction := ocean_to_land_ratio / (1.0 + ocean_to_land_ratio)
	var low_threshold := -2.0
	var high_threshold := 2.0
	var best_mask := PackedByteArray()
	var best_error := INF

	# Find a noise threshold whose final, widened water mask is near the
	# requested land-to-ocean ratio.
	for _iteration in range(16):
		var threshold := (low_threshold + high_threshold) * 0.5
		var trial_mask := _build_connected_water_mask(
			threshold,
			resolution,
			cell_size
		)

		var water_count := 0
		for index in range(trial_mask.size()):
			if trial_mask[index] != 0:
				water_count += 1

		var water_fraction := float(water_count) / float(trial_mask.size())
		var error := absf(water_fraction - target_ocean_fraction)

		if error < best_error:
			best_error = error
			best_mask = trial_mask
			_land_threshold = threshold

		# A higher threshold classifies more samples as candidate water.
		if water_fraction > target_ocean_fraction:
			high_threshold = threshold
		else:
			low_threshold = threshold

	return best_mask


func _build_connected_water_mask(
	threshold: float,
	resolution: int,
	cell_size: float
) -> PackedByteArray:
	var point_count := resolution * resolution
	var candidates := PackedByteArray()
	var connected := PackedByteArray()
	candidates.resize(point_count)
	connected.resize(point_count)

	for z in range(resolution):
		for x in range(resolution):
			var index := z * resolution + x
			var is_map_edge := (
				x == 0
				or z == 0
				or x == resolution - 1
				or z == resolution - 1
			)

			if is_map_edge or _land_fields[index] <= threshold:
				candidates[index] = 1

	# Seed a flood fill from every edge cell. This makes the edge ocean the
	# source of all water retained in the map.
	var queue := PackedInt32Array()

	for x in range(resolution):
		var top_index := x
		var bottom_index := (resolution - 1) * resolution + x

		connected[top_index] = 1
		queue.append(top_index)
		connected[bottom_index] = 1
		queue.append(bottom_index)

	for z in range(1, resolution - 1):
		var left_index := z * resolution
		var right_index := z * resolution + resolution - 1

		connected[left_index] = 1
		queue.append(left_index)
		connected[right_index] = 1
		queue.append(right_index)

	var queue_head := 0

	while queue_head < queue.size():
		var index := queue[queue_head]
		queue_head += 1

		var x := index % resolution
		var z := int(index / resolution)

		if x > 0:
			var left := index - 1
			if candidates[left] != 0 and connected[left] == 0:
				connected[left] = 1
				queue.append(left)

		if x < resolution - 1:
			var right := index + 1
			if candidates[right] != 0 and connected[right] == 0:
				connected[right] = 1
				queue.append(right)

		if z > 0:
			var up := index - resolution
			if candidates[up] != 0 and connected[up] == 0:
				connected[up] = 1
				queue.append(up)

		if z < resolution - 1:
			var down := index + resolution
			if candidates[down] != 0 and connected[down] == 0:
				connected[down] = 1
				queue.append(down)

	return _widen_water_mask(connected, resolution, cell_size)


func _widen_water_mask(
	water_mask: PackedByteArray,
	resolution: int,
	cell_size: float
) -> PackedByteArray:
	var widened := PackedByteArray()
	widened.resize(water_mask.size())

	# A square dilation gives every retained channel at least the requested
	# approximate width on this grid.
	var radius := ceili(
		maxf(0.0, minimum_channel_width_m) / (2.0 * cell_size)
	)

	if radius == 0:
		return water_mask

	for z in range(resolution):
		for x in range(resolution):
			var index := z * resolution + x
			if water_mask[index] == 0:
				continue

			for offset_z in range(-radius, radius + 1):
				var target_z := z + offset_z
				if target_z < 0 or target_z >= resolution:
					continue

				for offset_x in range(-radius, radius + 1):
					var target_x := x + offset_x
					if target_x < 0 or target_x >= resolution:
						continue

					widened[target_z * resolution + target_x] = 1

	return widened
