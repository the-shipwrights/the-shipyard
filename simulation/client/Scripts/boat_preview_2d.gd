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
