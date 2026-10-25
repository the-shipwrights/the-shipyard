@tool

extends MeshInstance3D
class_name WaterSurface

## Attach to the water MeshInstance3D (the one using water.gdshader).
## Reads the terrain's public data, so the terrain script stays untouched.

@export var terrain: TerrainWorld
@export var max_dist := 40.0 ## distances beyond this are treated as open ocean
@export var height_blur_passes := 1     ## smooths depth/coastline fed to the water
@export var distance_blur_passes := 3   ## smooths the shore-distance field

func _blur(src: PackedFloat32Array, n: int, passes: int) -> PackedFloat32Array:
	var a := src.duplicate()
	var b := src.duplicate()
	for _p in passes:
		for z in n:
			for x in n:
				var sum := 0.0
				var cnt := 0.0
				for dz in range(-1, 2):
					var zz := z + dz
					if zz < 0 or zz >= n:
						continue
					for dx in range(-1, 2):
						var xx := x + dx
						if xx < 0 or xx >= n:
							continue
						sum += a[zz * n + xx]
						cnt += 1.0
				b[z * n + x] = sum / cnt
		var tmp := a
		a = b
		b = tmp
	return a

func _ready() -> void:
	# Let the terrain finish generating its heights in its own _ready()
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

	var n := terrain.resolution
	var half := (n - 1) * terrain.CELL_SIZE * 0.5

	var smooth_h := _blur(terrain.heights, n, height_blur_passes)
	var smooth_d := _blur(_distance_field(smooth_h), n, distance_blur_passes)

	var h_img := Image.create_from_data(n, n, false, Image.FORMAT_RF, smooth_h.to_byte_array())
	var d_img := Image.create_from_data(n, n, false, Image.FORMAT_RF, smooth_d.to_byte_array())

	mat.set_shader_parameter("terrain_height", ImageTexture.create_from_image(h_img))
	mat.set_shader_parameter("shore_dist", ImageTexture.create_from_image(d_img))
	mat.set_shader_parameter("terrain_origin",
		Vector2(terrain.global_position.x - half, terrain.global_position.z - half))
	mat.set_shader_parameter("cell_size", terrain.CELL_SIZE)
	mat.set_shader_parameter("terrain_res", float(n))
	mat.set_shader_parameter("sea_level", terrain.sea_level)
	mat.set_shader_parameter("ocean_depth_m", terrain.ocean_depth_m)
	mat.set_shader_parameter("shore_max_dist", max_dist)


## Distance (in meters) from each cell to the nearest land cell.
## Classic two-pass chamfer distance transform.
func _distance_field(h: PackedFloat32Array) -> PackedFloat32Array:
	var n := terrain.resolution
	var d := PackedFloat32Array()
	d.resize(n * n)
	for i in n * n:
		d[i] = 0.0 if h[i] >= terrain.sea_level else 1.0e9

	var a := 0.9604   # better-fitting chamfer weights than 1.0 / 1.4142,
	var b := 1.3693   # less octagonal

	# Forward pass
	for z in n:
		for x in n:
			var i := z * n + x
			var v := d[i]
			if x > 0:
				v = minf(v, d[i - 1] + a)
			if z > 0:
				v = minf(v, d[i - n] + a)
				if x > 0:
					v = minf(v, d[i - n - 1] + b)
				if x < n - 1:
					v = minf(v, d[i - n + 1] + b)
			d[i] = v

	# Backward pass
	for z in range(n - 1, -1, -1):
		for x in range(n - 1, -1, -1):
			var i := z * n + x
			var v := d[i]
			if x < n - 1:
				v = minf(v, d[i + 1] + a)
			if z < n - 1:
				v = minf(v, d[i + n] + a)
				if x < n - 1:
					v = minf(v, d[i + n + 1] + b)
				if x > 0:
					v = minf(v, d[i + n - 1] + b)
			d[i] = v

	for i in n * n:
		d[i] = minf(d[i] * terrain.CELL_SIZE, max_dist)
	return d
