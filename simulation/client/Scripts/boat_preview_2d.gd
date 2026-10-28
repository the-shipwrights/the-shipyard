@tool
extends Control
class_name BoatPreview2D

signal placement_selected(piece_id: int, location: Vector2i)

const OUTLINE_COLOR := Color("#15232a")

const PIECE_TYPES := {
	0: {"width": 6.0, "height": 4.0, "shape": "bow", "color_field": "primary"},
	1: {"width": 4.0, "height": 4.0, "shape": "rect", "color_field": "primary"},
	2: {"width": 4.0, "height": 4.0, "shape": "stern", "color_field": "primary"},
	3: {"width": 4.0, "height": 3.0, "shape": "rect", "color_field": "secondary"},
	4: {"width": 4.0, "height": 6.0, "shape": "rect", "color_field": "secondary"},
	11: {"width": 1.0, "height": 4.0, "shape": "chimney", "color_field": "accent"},
}


## Waterline as a fraction of screen height, measured from the TOP of the screen.
## Everything (waves, gradient, boat) hangs off this one value, so tune it in the Inspector.
@export_range(0.2, 0.9, 0.005) var ocean_level := 0.6
## Horizontal boat position as a fraction of screen width.
@export_range(0.0, 1.0, 0.01) var boat_x := 0.5
## Largest the boat may get, as a fraction of the screen.
@export_range(0.1, 1.0, 0.01) var boat_max_width := 0.5
@export_range(0.1, 1.0, 0.01) var boat_max_height := 0.3
## Draw a simple sky gradient above the water.
@export var draw_sky := true


const SKY_TOP := Color("#87CEEB")
const SKY_BOTTOM := Color("#e4f5f8")
const BACK_WAVE_COLOR := Color("#08404a")
const FRONT_WAVE_COLOR := Color("#008080")
## The colour the water fades to at the bottom of the screen.
const DEEP_TEAL := Color("#08404a")
## The gradient starts this many px above the wave's base line
const GRADIENT_LEAD := 24.0

const BOB_AMPLITUDE := 3.0     # extra vertical bob on top of following the swell (px)
const BOB_SPEED := 1.3         # rad/s
const BOB_WAVE_GAIN := 1.0     # 1.0 = rides the surface exactly, >1 exaggerates it
const ROLL_AMPLITUDE_DEG := 4.0  # extra slow rocking on top of the wave slope
const ROLL_SPEED := 0.9        # rad/s
const TILT_FROM_WAVES := 1.0   # how much of the surface slope the boat copies
const MAX_TILT := 0.35         # radians (~20 degrees)

const WAVE_STEP := 4.0
const WAVE_MARGIN := 40.0
const STEEPNESS := 0.5  # peaked crests; keep the sum of amp*k*steepness below 1

# amplitude (px), wavelength (px), heave speed (rad/s), phase
const SWELLS := [
	[5.0, 280.0, 0.7, 0.0],
	[6.0, 220.0, 0.9, 2.1],
	[4.0, 140.0, 1.0, 3.0],
]

var _time := 0.0

const PIECE_CATALOG := preload("res://Scripts/piece_catalog.gd")
var _piece_configs: Dictionary = PIECE_CATALOG.PIECE_CONFIGS
var _candidate_piece_id := -1
var _placement_candidates: Array[Vector2i] = []
var _candidate_rects: Array[Rect2] = []
var _pieces: Array = []

# Transform applied to the boat (rotation about the waterline). Kept so that
# clicks can be mapped back into the boat's un-rotated space.
var _boat_xf := Transform2D.IDENTITY

var _customization := {
	"primary": Color("#2f7fff"),
	"secondary": Color("#ffffff"),
	"accent": Color("#ff8800"),
}


func _ready() -> void:
	clip_contents = true
	# Fill the whole screen. (This is ignored if the parent is a Container -
	# make this node a direct child of your root Control / CanvasLayer, and
	# put it FIRST so the palette and Launch button draw on top of it.)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ---------------------------------------------------------------------------
# Public API (unchanged)
# ---------------------------------------------------------------------------

func set_customization(colors: Dictionary) -> void:
	for field in ["primary", "secondary", "accent"]:
		if not colors.has(field):
			continue

		var value: Variant = colors[field]
		if value is Color:
			_customization[field] = value
		else:
			_customization[field] = Color.from_string(
				str(value),
				_customization[field]
			)

	queue_redraw()


func set_boat(data: Dictionary) -> void:
	var structure: Dictionary = data.get("boat", data)
	var raw_pieces: Variant = structure.get("pieces", [])
	_pieces = raw_pieces if raw_pieces is Array else []
	_customization = {
		"primary": Color("#2f7fff"),
		"secondary": Color("#ffffff"),
		"accent": Color("#ff8800"),
	}
	set_customization(data.get("customization", {}))
	queue_redraw()


func set_placement_candidates(piece_id: int, locations: Array[Vector2i]) -> void:
	_placement_candidates = locations.duplicate()
	_candidate_piece_id = piece_id if not locations.is_empty() else -1
	_candidate_rects.clear()
	queue_redraw()


func clear_boat() -> void:
	_pieces.clear()
	_candidate_piece_id = -1
	_placement_candidates.clear()
	_candidate_rects.clear()
	queue_redraw()


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	_candidate_rects.clear()
	_boat_xf = Transform2D.IDENTITY

	var waterline := size.y * ocean_level

	if draw_sky:
		_draw_sky(waterline)

	_draw_wave(waterline - 12.0, 0.75, 0.8, 1.0, BACK_WAVE_COLOR)

	var bounds := _boat_bounds()
	if bounds.has_area():
		var boat_size := bounds.size
		var available := Vector2(size.x * boat_max_width, size.y * boat_max_height)
		var scale_factor := minf(
			available.x / boat_size.x,
			available.y / boat_size.y
		)
		var boat_px := boat_size * scale_factor

		var cx := size.x * boat_x

		# Bob: follow the surface under the boat, plus an extra slow bob.
		var bob := _wave_offset(cx, 1.0, 1.0, 0.0).y * BOB_WAVE_GAIN
		bob += sin(_time * BOB_SPEED) * BOB_AMPLITUDE

		# Tilt: copy the surface slope across the boat's width, plus a slow roll.
		var tilt := _boat_tilt(cx, maxf(boat_px.x * 0.5, 20.0))

		# The boat sits a quarter of its height below the waterline.
		var center := Vector2(cx, waterline - boat_px.y * 0.25 + bob)
		var world_center := bounds.get_center()

		# Rotate about the point where the boat meets the water.
		var pivot := Vector2(cx, waterline + bob)
		var rot := Transform2D(tilt, Vector2.ZERO)
		_boat_xf = Transform2D(tilt, pivot - rot * pivot)

		draw_set_transform_matrix(_boat_xf)
		_draw_placement_candidates(world_center, center, scale_factor)
		for piece in _pieces:
			if piece is Dictionary:
				_draw_piece(piece, world_center, center, scale_factor)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	_draw_wave(waterline, 1.0, 1.0, 0.0, FRONT_WAVE_COLOR)


func _boat_bounds() -> Rect2:
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF

	for piece in _pieces:
		if not (piece is Dictionary):
			continue

		var piece_id := int(piece.get("id", -1))
		var config: Dictionary = _piece_configs.get(piece_id, {})
		if config.is_empty():
			continue

		var x := float(piece.get("x", 0))
		var y := float(piece.get("y", 0))
		var width := float(config["width"])
		var height := float(config["height"])

		min_x = minf(min_x, x)
		min_y = minf(min_y, y)
		max_x = maxf(max_x, x + width)
		max_y = maxf(max_y, y + height)

	if min_x == INF:
		return Rect2()
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


func _boat_tilt(cx: float, half_width: float) -> float:
	var left := _wave_offset(cx - half_width, 1.0, 1.0, 0.0).y
	var right := _wave_offset(cx + half_width, 1.0, 1.0, 0.0).y
	# Screen y points down, so a lower right side gives a positive
	# (clockwise) angle - the same way the surface leans.
	var slope := atan2(right - left, half_width * 2.0)
	var roll := deg_to_rad(ROLL_AMPLITUDE_DEG) * sin(_time * ROLL_SPEED)
	return clampf(slope * TILT_FROM_WAVES + roll, -MAX_TILT, MAX_TILT)


func _draw_sky(waterline: float) -> void:
	var bottom := waterline + 40.0  # hidden behind the water
	draw_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(size.x, 0.0),
			Vector2(size.x, bottom),
			Vector2(0.0, bottom),
		]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM])
	)


func _draw_placement_candidates(
	world_center: Vector2,
	screen_center: Vector2,
	scale_factor: float
) -> void:
	var config: Dictionary = _piece_configs.get(_candidate_piece_id, {})
	if config.is_empty():
		return

	var candidate_width := float(config["width"])
	var candidate_height := float(config["height"])

	for location in _placement_candidates:
		var top_left := _world_to_screen(
			Vector2(location.x, location.y + candidate_height),
			world_center,
			screen_center,
			scale_factor
		)
		var rect := Rect2(
			top_left,
			Vector2(candidate_width * scale_factor, candidate_height * scale_factor)
		)
		_candidate_rects.append(rect)
		draw_rect(rect, Color(0.8, 0.6, 0.3, 0.35), true)
		draw_rect(rect, Color("#ffd166"), false, 2.0)


func _world_to_screen(
	world_point: Vector2,
	world_center: Vector2,
	screen_center: Vector2,
	scale_factor: float
) -> Vector2:
	return screen_center + Vector2(
		(world_point.x - world_center.x) * scale_factor,
		-(world_point.y - world_center.y) * scale_factor
	)


func _shape_points(shape: String, width: float, height: float) -> PackedVector2Array:
	match shape:
		"bow":
			return PackedVector2Array([
				Vector2(0, 0),
				Vector2(width, height*0.75),
				Vector2(width, height),
				Vector2(0, height),
			])
		"stern":
			return PackedVector2Array([
				Vector2(0, height*0.5),
				Vector2(width, 0),
				Vector2(width, height),
				Vector2(0, height),
			])
		"hull":
			return PackedVector2Array([
				Vector2(0, 0),
				Vector2(width, 0),
				Vector2(width, height),
				Vector2(0, height),
			])
		"cabin":
			return PackedVector2Array([
				Vector2(0, 0),
				Vector2(width*0.8, 0),
				Vector2(width*0.8, height*1.5),
				Vector2(0, height*1.5),
			])
		"big_cabin":
			return PackedVector2Array([
				Vector2(0, 0),
				Vector2(width, 0),
				Vector2(width, height*2),
				Vector2(0, height*2),
			])
		"chimney":
			return PackedVector2Array([
				Vector2(0, 0),
				Vector2(width, 0),
				Vector2(width, height),
				Vector2(0, height),
			])
		"sail":
			return PackedVector2Array([
				Vector2(-2, 0),
				Vector2(width-2, height),
				Vector2(width-2, 0),
			])
		_:
			return PackedVector2Array([
				Vector2(0, 0),
				Vector2(width, 0),
				Vector2(width, height),
				Vector2(0, height),
			])


func _draw_piece(
	piece: Dictionary,
	world_center: Vector2,
	screen_center: Vector2,
	scale_factor: float
) -> void:
	var piece_id := int(piece.get("id", -1))
	var config: Dictionary = _piece_configs.get(piece_id, {})
	if config.is_empty():
		return

	var width := float(config["width"])
	var height := float(config["height"])
	var piece_x := float(piece.get("x", 0))
	var piece_y := float(piece.get("y", 0))
	var flipped := bool(piece.get("flipped", false))
	var shape := str(config.get("shape", "rect"))
	var color_field := str(config.get("color_field", "primary"))

	var local_points := _shape_points(shape, width, height)
	var screen_points := PackedVector2Array()

	for point in local_points:
		var local_x := width - point.x if flipped else point.x
		var world_point := Vector2(piece_x + local_x, piece_y + point.y)
		var screen_point := screen_center + Vector2(
			(world_point.x - world_center.x) * scale_factor,
			-(world_point.y - world_center.y) * scale_factor
		)
		screen_points.append(screen_point)

	var piece_color: Color = _customization.get(
		color_field,
		_customization["primary"]
	)
	draw_colored_polygon(screen_points, piece_color)

	for i in range(screen_points.size()):
		draw_line(
			screen_points[i],
			screen_points[(i + 1) % screen_points.size()],
			OUTLINE_COLOR,
			2.0,
			true  # antialiased - edges are rotated now
		)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	# Candidate rects live in the boat's un-rotated space, so undo the tilt.
	var local_pos := _boat_xf.affine_inverse() * mb.position

	for i in range(_candidate_rects.size() - 1, -1, -1):
		if _candidate_rects[i].has_point(local_pos):
			placement_selected.emit(_candidate_piece_id, _placement_candidates[i])
			accept_event()
			return


# ---------------------------------------------------------------------------
# Waves
# ---------------------------------------------------------------------------

func _wave_offset(
	x0: float,
	amp_scale: float,
	speed_scale: float,
	phase_offset: float
) -> Vector2:
	var offset := Vector2.ZERO

	for w in SWELLS:
		var amp: float = w[0] * amp_scale
		var spatial: float = x0 * TAU / w[1] + w[3] + phase_offset + _time * 0.05
		var heave: float = _time * w[2] * speed_scale + w[3] * 1.7 + phase_offset
		# Fixed shape in x, pulsing in time: up and down, not sliding sideways.
		offset.y -= amp * sin(spatial) * sin(heave)

	return offset


func _draw_wave(
	base_y: float,
	amp_scale: float,
	speed_scale: float,
	phase_offset: float,
	color: Color
) -> void:
	var span := size.x + WAVE_MARGIN * 2.0
	var steps := int(ceil(span / WAVE_STEP))
	var crest := PackedVector2Array()

	for i in range(steps + 1):
		var x0 := -WAVE_MARGIN + span * float(i) / float(steps)
		var o := _wave_offset(x0, amp_scale, speed_scale, phase_offset)
		crest.append(Vector2(x0 + o.x, base_y + o.y))

	var bottom := size.y + 10.0
	var polygon := crest.duplicate()
	polygon.append(Vector2(crest[-1].x, bottom))
	polygon.append(Vector2(crest[0].x, bottom))

	# Vertical gradient: wave colour at the surface -> deep teal at screen bottom.
	# Colour is a linear function of y, so per-vertex colours interpolate exactly.
	var top := base_y - GRADIENT_LEAD
	var span_y := maxf(bottom - top, 1.0)
	var colors := PackedColorArray()
	for p in polygon:
		var t := clampf((p.y - top) / span_y, 0.0, 1.0)
		colors.append(color.lerp(DEEP_TEAL, t))

	draw_polygon(polygon, colors)
	draw_polyline(crest, color.lightened(0.35), 2.0, true)
