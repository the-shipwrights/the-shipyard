@tool
extends RefCounted
class_name TerrainGenerator

var seed := 2026

var _ocean_to_land_ratio: float
var _minimum_channel_width_m: float
var _coast_shelf_width_m: float
var _sea_level: float
var _ocean_depth_m: float
var _island_scale_m: float
var _mountain_scale_m: float
var _mountain_height_m: float

var base_relief_m := 8.0
var relief_amplitude_m := 1.5
var max_land_height_m := 40.0

var _land_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _warp_noise: FastNoiseLite
var _height_noise: FastNoiseLite

var _mountain_peaks := PackedVector3Array()
var _land_fields := PackedFloat32Array()
var _water_mask := PackedByteArray()
var _land_threshold := 0.0
var _land_field_max := 1.0


func configure(
	world_seed: int,
	world_ocean_to_land_ratio: float,
	channel_width_m: float,
	world_coast_shelf_width_m: float,
	world_sea_level: float,
	world_ocean_depth_m: float,
	world_island_scale_m: float,
	world_mountain_scale_m: float,
	world_mountain_height_m: float
) -> void:
	seed = world_seed
	_ocean_to_land_ratio = maxf(world_ocean_to_land_ratio, 0.01)
	_minimum_channel_width_m = maxf(channel_width_m, 0.0)
	_coast_shelf_width_m = maxf(world_coast_shelf_width_m, 0.1)
	_sea_level = world_sea_level
	_ocean_depth_m = maxf(world_ocean_depth_m, 0.1)
	_island_scale_m = maxf(world_island_scale_m, 1.0)
	_mountain_scale_m = maxf(world_mountain_scale_m, 1.0)
	_mountain_height_m = maxf(world_mountain_height_m, 0.0)

	# Low-octave noise controls large land regions.
	_land_noise = _make_noise(seed, 1.0 / _island_scale_m, 1, FastNoiseLite.FRACTAL_FBM)

	# small contribution to the coast shape, not the main
	# source of land and water patches.
	_detail_noise = _make_noise(seed + 1, 2.0 / _island_scale_m, 1, FastNoiseLite.FRACTAL_FBM)

	_warp_noise = _make_noise(seed + 2, 1.0 / _island_scale_m, 1, FastNoiseLite.FRACTAL_FBM)

	# broad elevation variation across the land interior.
	_height_noise = _make_noise(seed + 3, 1.0 / _mountain_scale_m, 2, FastNoiseLite.FRACTAL_FBM)


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
	var warp_strength := _island_scale_m * 0.025
	var warp_x := _warp_noise.get_noise_2d(x, z) * warp_strength
	var warp_z := _warp_noise.get_noise_2d(x + 731.0, z - 419.0) * warp_strength

	var broad_shape := _land_noise.get_noise_2d(x + warp_x, z + warp_z)
	var coast_detail := _detail_noise.get_noise_2d(x, z)

	# Broad noise decides land versus ocean. Detail only gently perturbs the coastline so it does not break the land into small patches.
	return broad_shape * 0.98 + coast_detail * 0.02


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

	var coast_distance_cells := _build_coast_distance_cells(resolution)
	# Random mountain peaks, testing gradual landmass heights from coast instead
	# _mountain_peaks = _generate_mountain_peaks(resolution, cell_size)

	var heights := PackedFloat32Array()
	heights.resize(point_count)

	for z in range(resolution):
		for x in range(resolution):
			var local_x := float(x) * cell_size - half_extent
			var local_z := float(z) * cell_size - half_extent
			var index := z * resolution + x

			var coast_distance_m := (
				float(coast_distance_cells[index]) * cell_size
			)
			var coast_progress := _smoothstep01(
				coast_distance_m / _coast_shelf_width_m
			)

			if _water_mask[index] != 0:
				heights[index] = lerpf(
					_sea_level - 0.05,
					_sea_level - _ocean_depth_m,
					coast_progress
				)
				continue

			# Previous landheight calculations
			"""
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

			var mountain_coast_weight := _smoothstep01(
				coast_distance_m / maxf(_mountain_scale_m * 0.5, cell_size)
			)
			var mountain_relief := (
				_mountain_relief_at(local_x, local_z) * mountain_coast_weight
			)
			var base_relief := coast_progress * (
				1.0
				+ inland * maxf(0.0, base_relief_m + broad_relief)
			)
			var land_height := _sea_level + 0.05 + base_relief + mountain_relief

			heights[index] = clampf(
				land_height,
				_sea_level + 0.05,
				_sea_level + max_land_height_m + _mountain_height_m
			)
			"""

			var inland_rise_distance_m := maxf(
				_island_scale_m * 0.75,
				cell_size
			)
			var inland_progress := _smoothstep01(
				coast_distance_m / inland_rise_distance_m
			)

			# Convert smooth noise from approximately -1..1 to 0..1.
			# This gives many broad interior highs and lows instead of a
			# few separately placed mountain peaks.
			var height_pattern := clampf(
				0.5 + 0.5 * _height_noise.get_noise_2d(local_x, local_z),
				0.0,
				1.0
			)

			# Every island rises away from its coastline. The height pattern changes the inland relief across the map.
			var interior_relief := base_relief_m + _mountain_height_m * lerpf(
				0.25,
				1.0,
				height_pattern
			)

			var land_height := (
				_sea_level
				+ 0.05
				+ inland_progress * interior_relief
			)

			heights[index] = clampf(
				land_height,
				_sea_level + 0.05,
				_sea_level + max_land_height_m + _mountain_height_m
			)
	return heights


func _find_water_mask(resolution: int, cell_size: float) -> PackedByteArray:
	var target_ocean_fraction := _ocean_to_land_ratio / (1.0 + _ocean_to_land_ratio)
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
		maxf(0.0, _minimum_channel_width_m) / (2.0 * cell_size)
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

func _build_coast_distance_cells(resolution: int) -> PackedInt32Array:
	var point_count := resolution * resolution
	var distances := PackedInt32Array()
	distances.resize(point_count)
	distances.fill(point_count + 1)

	var queue := PackedInt32Array()

	for z in range(resolution):
		for x in range(resolution):
			var index := z * resolution + x
			var touches_coast := false

			if x < resolution - 1:
				var right := index + 1
				if _water_mask[index] != _water_mask[right]:
					touches_coast = true

			if z < resolution - 1:
				var down := index + resolution
				if _water_mask[index] != _water_mask[down]:
					touches_coast = true

			if touches_coast:
				distances[index] = 0
				queue.append(index)

	var queue_head := 0

	while queue_head < queue.size():
		var index := queue[queue_head]
		queue_head += 1

		var x := index % resolution
		var z := int(index / resolution)
		var next_distance := distances[index] + 1

		if x > 0:
			var left := index - 1
			if next_distance < distances[left]:
				distances[left] = next_distance
				queue.append(left)

		if x < resolution - 1:
			var right := index + 1
			if next_distance < distances[right]:
				distances[right] = next_distance
				queue.append(right)

		if z > 0:
			var up := index - resolution
			if next_distance < distances[up]:
				distances[up] = next_distance
				queue.append(up)

		if z < resolution - 1:
			var down := index + resolution
			if next_distance < distances[down]:
				distances[down] = next_distance
				queue.append(down)

	return distances


func _smoothstep01(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _generate_mountain_peaks(
	resolution: int,
	cell_size: float
) -> PackedVector3Array:
	var peaks := PackedVector3Array()
	var land_point_count := 0

	for index in range(_water_mask.size()):
		if _water_mask[index] == 0:
			land_point_count += 1

	var peak_count := clampi(
		roundi(float(land_point_count) / 1200.0),
		0,
		12
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 4

	var half_extent := float(resolution - 1) * cell_size * 0.5
	var attempts_left := peak_count * 100

	while peaks.size() < peak_count and attempts_left > 0:
		attempts_left -= 1

		var grid_x := rng.randi_range(0, resolution - 1)
		var grid_z := rng.randi_range(0, resolution - 1)
		var index := grid_z * resolution + grid_x

		if _water_mask[index] != 0:
			continue

		var local_x := float(grid_x) * cell_size - half_extent
		var local_z := float(grid_z) * cell_size - half_extent
		var too_close := false

		for existing_peak in peaks:
			var separation := Vector2(
				local_x - existing_peak.x,
				local_z - existing_peak.z
			).length()

			if separation < _mountain_scale_m:
				too_close = true
				break

		if too_close:
			continue

		var peak_height := rng.randf_range(
			_mountain_height_m * 0.65,
			_mountain_height_m
		)
		peaks.append(Vector3(local_x, peak_height, local_z))

	return peaks


func _mountain_relief_at(x: float, z: float) -> float:
	var relief := 0.0
	var radius := maxf(_mountain_scale_m, 0.1)

	for peak in _mountain_peaks:
		var distance := Vector2(x - peak.x, z - peak.z).length()
		var normalized_distance := distance / radius

		if normalized_distance >= 1.0:
			continue

		# A quadratic falloff in squared distance gives a rounded peak
		# with a gentle top and a smooth edge.
		var falloff := 1.0 - normalized_distance * normalized_distance
		var mound_height := peak.y * falloff * falloff
		relief = maxf(relief, mound_height)

	return relief
