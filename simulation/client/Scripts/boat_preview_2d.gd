extends Control
class_name BoatPreview2D

signal cabin_location_selected(location: Vector2i)

var _cabin_candidates: Array[Vector2i] = []
var _candidate_rects: Array[Rect2] = []

const PADDING := 16.0
const OUTLINE_COLOR := Color("#15232a")

const PIECE_TYPES := {
	0: {
		"width": 6.0, "height": 4.0, "shape": "bow",
		"color": Color("#4c83a8")
	},
	1: {
		"width": 4.0, "height": 4.0, "shape": "rect",
		"color": Color("#598bad")
	},
	2: {
		"width": 4.0, "height": 4.0, "shape": "stern",
		"color": Color("#416f91")
	},
	3: {
		"width": 4.0, "height": 3.0, "shape": "rect",
		"color": Color("#c99554")
	},
}

var _pieces: Array = []


func set_boat(data: Dictionary) -> void:
	var structure: Dictionary = data.get("boat", data)
	var raw_pieces: Variant = structure.get("pieces", [])
	_pieces = raw_pieces if raw_pieces is Array else []
	queue_redraw()


func set_cabin_candidates(locations: Array[Vector2i]) -> void:
	_cabin_candidates = locations.duplicate()
	queue_redraw()

func clear_boat() -> void:
	_pieces.clear()
	queue_redraw()


func _draw() -> void:
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
	var scale_factor := minf(
		available.x / maxf(boat_size.x, 1.0),
		available.y / maxf(boat_size.y, 1.0)
	)
	var center := size / 2.0
	var world_center := Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)

	for piece in _pieces:
		if piece is Dictionary:
			_draw_piece(piece, world_center, center, scale_factor)
	
	# Cabin config
	var cabin_config: Dictionary = PIECE_TYPES[3]

	for location in _cabin_candidates:
		min_x = minf(min_x, location.x)
		min_y = minf(min_y, location.y)
		max_x = maxf(max_x, location.x + cabin_config["width"])
		max_y = maxf(max_y, location.y + cabin_config["height"])
	
	_candidate_rects.clear()

	var cabin_width: float = PIECE_TYPES[3]["width"]
	var cabin_height: float = PIECE_TYPES[3]["height"]

	for location in _cabin_candidates:
		var top_left := _world_to_screen(
			Vector2(location.x, location.y + cabin_height),
			world_center,
			center,
			scale_factor
		)
		var rect := Rect2(
			top_left,
			Vector2(cabin_width * scale_factor, cabin_height * scale_factor)
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

	draw_colored_polygon(screen_points, config["color"])

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
			cabin_location_selected.emit(_cabin_candidates[i])
			accept_event()
			return
