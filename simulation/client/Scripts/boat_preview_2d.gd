extends Control
class_name BoatPreview2D

signal placement_selected(piece_id: int, location: Vector2i)

var _candidate_piece_id := -1
var _placement_candidates: Array[Vector2i] = []
var _candidate_rects: Array[Rect2] = []

const PADDING := 16.0
const OUTLINE_COLOR := Color("#15232a")

const PIECE_TYPES := {
	0: {"width": 6.0, "height": 4.0, "shape": "bow", "color_field": "primary"},
	1: {"width": 4.0, "height": 4.0, "shape": "rect", "color_field": "primary"},
	2: {"width": 4.0, "height": 4.0, "shape": "stern", "color_field": "primary"},
	3: {"width": 4.0, "height": 3.0, "shape": "rect", "color_field": "secondary"},
	4: {"width": 4.0, "height": 6.0, "shape": "rect", "color_field": "secondary"},
	11: {"width": 1.0, "height": 4.0, "shape": "chimney", "color_field": "accent"},
}

const BACK_WAVE_COLOR := Color("#3f86b5")
const FRONT_WAVE_COLOR := Color("#5aa9d6")
const BOB_AMPLITUDE := 3.0
const BOB_SPEED := 1.1
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

var _pieces: Array = []

var _customization := {
	"primary": Color("#2f7fff"),
	"secondary": Color("#ffffff"),
	"accent": Color("#ff8800"),
}

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


func _draw() -> void:
	_candidate_rects.clear()
	if _pieces.is_empty():
		return

	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF

	for piece in _pieces:
		if not (piece is Dictionary):
			continue

		var config: Dictionary = PIECE_TYPES.get(int(piece.get("id", -1)), {})
		if config.is_empty():
			continue

		var x := float(piece.get("x", 0))
		var y := float(piece.get("y", 0))
		min_x = minf(min_x, x)
		min_y = minf(min_y, y)
		max_x = maxf(max_x, x + config["width"])
		max_y = maxf(max_y, y + config["height"])

	if min_x == INF:
		return

	var boat_size := Vector2(max_x - min_x, max_y - min_y)
	var available := size - Vector2(PADDING * 2.0, PADDING * 2.0)
	available.y *= 0.75  # leave room for water below the boat
	var scale_factor := minf(
		available.x / maxf(boat_size.x, 1.0),
		available.y / maxf(boat_size.y, 1.0)
	)

	var base_center := size / 2.0 - Vector2(0.0, size.y * 0.1)
	var bob := _wave_offset(size.x * 0.5, 1.0, 1.0, 0.0).y * 0.6
	var center := base_center + Vector2(0.0, bob)
	var world_center := Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)

	# The waterline sits a quarter of the way up from the bottom of the boat.
	var waterline := base_center.y + boat_size.y * scale_factor * 0.25

	_draw_wave(waterline - 12.0, 0.75, 0.8, 1.0, BACK_WAVE_COLOR)

	for piece in _pieces:
		if piece is Dictionary:
			_draw_piece(piece, world_center, center, scale_factor)

	_draw_wave(waterline, 1.0, 1.0, 0.0, FRONT_WAVE_COLOR)

	# Candidate config
	var candidate_config: Dictionary = PIECE_TYPES.get(_candidate_piece_id, {})
	if candidate_config.is_empty():
		return

	var candidate_width := float(candidate_config["width"])
	var candidate_height := float(candidate_config["height"])

	for location in _placement_candidates:
		var top_left := _world_to_screen(
			Vector2(location.x, location.y + candidate_height),
			world_center,
			center,
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
	var config: Dictionary = PIECE_TYPES.get(int(piece.get("id", -1)), {})
	if config.is_empty():
		return

	var width: float = config["width"]
	var height: float = config["height"]
	var piece_x := float(piece.get("x", 0))
	var piece_y := float(piece.get("y", 0))
	var flipped := bool(piece.get("flipped", false))
	var local_points := _shape_points(config["shape"], width, height)
	var screen_points := PackedVector2Array()

	for point in local_points:
		var local_x := width - point.x if flipped else point.x
		var world_point := Vector2(piece_x + local_x, piece_y + point.y)
		var screen_point := screen_center + Vector2(
			(world_point.x - world_center.x) * scale_factor,
			-(world_point.y - world_center.y) * scale_factor
		)
		screen_points.append(screen_point)

	draw_colored_polygon(screen_points, _customization[config["color_field"]])

	for i in range(screen_points.size()):
		draw_line(
			screen_points[i],
			screen_points[(i + 1) % screen_points.size()],
			OUTLINE_COLOR,
			2.0
		)

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	for i in range(_candidate_rects.size() - 1, -1, -1):
		if _candidate_rects[i].has_point(event.position):
			placement_selected.emit(_candidate_piece_id, _placement_candidates[i])
			accept_event()
			return
			

func _ready() -> void:
	clip_contents = true
	
func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	


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

	var polygon := crest.duplicate()
	polygon.append(Vector2(crest[-1].x, size.y + 10.0))
	polygon.append(Vector2(crest[0].x, size.y + 10.0))

	draw_colored_polygon(polygon, color)
	draw_polyline(crest, color.lightened(0.35), 2.0)
