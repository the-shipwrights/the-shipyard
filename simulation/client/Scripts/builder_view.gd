extends Control

signal boat_created(boat_data: Dictionary)

# Piece metadata matching boat.py definitions[cite: 1]
const PIECE_CONFIGS := {
	0: {"name": "hull_bow", "width": 6, "height": 4, "category": "hull", "color": Color(0.3, 0.5, 0.7)},
	1: {"name": "hull_section", "width": 4, "height": 4, "category": "hull", "color": Color(0.35, 0.55, 0.75)},
	2: {"name": "hull_stern", "width": 4, "height": 4, "category": "hull", "color": Color(0.3, 0.5, 0.7)},
	3: {"name": "cabin", "width": 4, "height": 3, "category": "middle", "color": Color(0.8, 0.6, 0.3)},
	4: {"name": "big_cabin", "width": 4, "height": 6, "category": "middle", "color": Color(0.8, 0.6, 0.3)},
	11: {"name": "chimney", "width": 1, "height": 4, "category": "middle", "color": Color(0.8, 0.6, 0.3)},
}

const HULL_BOW := 0
const HULL_SECTION := 1
const HULL_STERN := 2
const CABIN := 3
const BIG_CABIN := 4
const CHIMNEY := 11

const BODY_PIECE_IDS := [
	HULL_STERN,
	HULL_SECTION,
	HULL_BOW,
]

const CABIN_PIECE_IDS := [CABIN, BIG_CABIN]

const CHIMNEY_HOST_IDS := [
	HULL_STERN,
	HULL_SECTION,
	HULL_BOW,
	CABIN,
]

const ACCESSORY_POINTS := {
	HULL_BOW: [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)],
	HULL_SECTION: [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)],
	HULL_STERN: [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)],
	CABIN: [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
}

var piece_instances: Array[Dictionary] = []
var next_piece_id: int = 0
var submit_request := HTTPRequest.new()

@onready var status_label: Label = $StatusLabel
@onready var submit_button: Button = $ActionsContainer/SubmitButton
@onready var reset_button: Button = $ActionsContainer/ResetButton

# Palette buttons
@onready var btn_bow: Button = $PaletteGrid/AddHullBow
@onready var btn_section: Button = $PaletteGrid/AddHullSection
@onready var btn_stern: Button = $PaletteGrid/AddHullStern
@onready var btn_cabin: Button = $PaletteGrid/AddCabin
@onready var btn_big_cabin: Button = $PaletteGrid/AddBigCabin
@onready var btn_chimney: Button = $PaletteGrid/AddChimney

@onready var boat_preview: BoatPreview2D = $CanvasPanel/BoatPreview2D

func _ready() -> void:
	add_child(submit_request)
	submit_request.request_completed.connect(_on_submit_completed)

	btn_bow.pressed.connect(func(): _add_piece(0))
	btn_section.pressed.connect(func(): _add_piece(1))
	btn_stern.pressed.connect(func(): _add_piece(2))

	btn_cabin.pressed.connect(_begin_cabin_placement.bind(CABIN))
	btn_big_cabin.pressed.connect(_begin_cabin_placement.bind(BIG_CABIN))
	btn_chimney.pressed.connect(_begin_chimney_placement)
	
	boat_preview.placement_selected.connect(_on_preview_placement_selected)

	reset_button.pressed.connect(clear_builder)
	submit_button.pressed.connect(submit_boat)

func _on_preview_placement_selected(piece_id: int, location: Vector2i) -> void:
	match piece_id:
		CABIN, BIG_CABIN:
			_on_cabin_location_selected(piece_id, location)
		CHIMNEY:
			_on_chimney_location_selected(location)

func clear_builder() -> void:
	piece_instances.clear()
	status_label.text = ""
	boat_preview.clear_boat()

func _add_piece(id: int) -> void:
	var config: Dictionary = PIECE_CONFIGS.get(id, {})
	if config.is_empty():
		status_label.text = "Unknown piece type."
		return

	if id not in BODY_PIECE_IDS:
		status_label.text = "Choose a highlighted placement."
		return

	var validation_error := _get_add_error(id)
	if not validation_error.is_empty():
		status_label.text = validation_error
		return
	
	var x_pos := 0
	var y_pos := 0
	piece_instances.append({
		"id": id,
		"x": _next_body_x(),
		"y": 0,
		"flipped": false,
		"colors": []
	})
	boat_preview.set_boat({"pieces": piece_instances})
	status_label.text = "Added " + str(config["name"])

func _find_first_piece_by_type(target_id: int):
	for p in piece_instances:
		if p["id"] == target_id:
			return p
	return null


func submit_boat() -> void:
	if piece_instances.is_empty():
		status_label.text = "Add at least one piece before submitting."
		return

	status_label.text = "Registering boat on backend..."
	submit_button.disabled = true

	# Match payload expected by FastAPI backend and submit_boat.py[cite: 2, 8]
	var payload := {
		"pieces": piece_instances,
		"edges": []
	}

	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := _get_api_base() + "/api/boats"
	var err := submit_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		status_label.text = "Failed to send request."
		submit_button.disabled = false

func _on_submit_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	submit_button.disabled = false

	if response_code != 200 and response_code != 201:
		status_label.text = "Submission failed (" + str(response_code) + ")"
		push_error("Backend rejected boat: " + body.get_string_from_utf8())
		return

	var response = JSON.parse_string(body.get_string_from_utf8())
	if not (response is Dictionary) or str(response.get("id", "")).is_empty():
		status_label.text = "Invalid response while creating boat."
		return

	status_label.text = "Boat created: " + str(response["id"])
	boat_created.emit(response)

func _get_api_base() -> String:
	if OS.has_feature("web"):
		var window = JavaScriptBridge.get_interface("window")
		return str(window.location.origin)
	return "http://127.0.0.1:8000"

## Validation helpers

func _body_pieces() -> Array[Dictionary]:
	var body: Array[Dictionary] = []

	for piece in piece_instances:
		var id := int(piece.get("id", -1))
		if id in BODY_PIECE_IDS:
			body.append(piece)

	return body


func _has_cabin() -> bool:
	for piece in piece_instances:
		if int(piece.get("id", -1)) == CABIN:
			return true

	return false


func _get_add_error(id: int) -> String:
	if not PIECE_CONFIGS.has(id):
		return "Unknown piece type."
		
	if id not in BODY_PIECE_IDS:
		return "This piece cannot be added to the boat body."

	var body := _body_pieces()

	# The first body piece may be a stern, hull section, or bow.
	if body.is_empty():
		return ""
	
	var last_id := int(body.back().get("id", -1))

	match last_id:
		HULL_STERN, HULL_SECTION, BIG_CABIN:
			if id in [HULL_SECTION, BIG_CABIN, HULL_BOW]:
				return ""
			return "A stern, hull, or big cabin can be followed by a hull, big cabin, or bow."

		HULL_BOW:
			return "The bow must be the last body piece."

	return "Invalid boat body."

func _next_body_x() -> int:
	var x := 0
	for piece in _body_pieces():
		var config: Dictionary = PIECE_CONFIGS[int(piece["id"])]
		x += int(config["width"])
	return x

func _get_open_cabin_locations(piece_id: int) -> Array[Vector2i]:
	var body := _body_pieces()
	var candidates: Array[Vector2i] = []

	if piece_id not in CABIN_PIECE_IDS:
		return candidates

	for piece in body:
		if int(piece.get("id", -1)) != HULL_SECTION:
			continue

		var section_config: Dictionary = PIECE_CONFIGS[HULL_SECTION]
		var location := Vector2i(
			int(piece.get("x", 0)),
			int(piece.get("y", 0)) + int(section_config["height"])
		)

		if not _cabin_position_occupied(location):
			candidates.append(location)

	if _is_stern_bow_body(body):
		var stern: Dictionary = body[0]
		var stern_x := int(stern.get("x", 0))
		var stern_width := int(PIECE_CONFIGS[HULL_STERN]["width"])
		var cabin_width := int(PIECE_CONFIGS[piece_id]["width"])
		var divide_x := stern_x + stern_width
		var location := Vector2i(divide_x - int(cabin_width / 2), 4)

		if not _cabin_position_occupied(location):
			candidates.append(location)

	return candidates


func _is_stern_bow_body(body: Array[Dictionary]) -> bool:
	return (
		body.size() == 2
		and int(body[0].get("id", -1)) == HULL_STERN
		and int(body[1].get("id", -1)) == HULL_BOW
	)


func _cabin_position_occupied(location: Vector2i) -> bool:
	for piece in piece_instances:
		if int(piece.get("id", -1)) not in CABIN_PIECE_IDS:
			continue

		if (
			int(piece.get("x", 0)) == location.x
			and int(piece.get("y", 0)) == location.y
		):
			return true

	return false

func _begin_cabin_placement(piece_id: int) -> void:
	var locations := _get_open_cabin_locations(piece_id)

	if locations.is_empty():
		status_label.text = "No open cabin attachment locations."
		boat_preview.set_placement_candidates(piece_id, [])
		return

	boat_preview.set_placement_candidates(piece_id, locations)
	status_label.text = "Select a highlighted cabin location."


func _on_cabin_location_selected(piece_id: int, location: Vector2i) -> void:
	if piece_id not in CABIN_PIECE_IDS:
		return

	# Recheck occupancy in case the available locations changed.
	if _cabin_position_occupied(location):
		status_label.text = "That cabin location is already occupied."
		_begin_cabin_placement(piece_id)
		return

	piece_instances.append({
		"id": piece_id,
		"x": location.x,
		"y": location.y,
		"flipped": false,
		"colors": []
	})

	boat_preview.set_placement_candidates(piece_id, [])
	boat_preview.set_boat({"pieces": piece_instances})
	status_label.text = "Added " + str(PIECE_CONFIGS[piece_id]["name"]) + "."

func _get_open_chimney_locations() -> Array[Vector2i]:
	var locations: Array[Vector2i] = []

	for piece in piece_instances:
		var host_id := int(piece.get("id", -1))
		if host_id not in CHIMNEY_HOST_IDS:
			continue
		
		if (
			host_id in [HULL_STERN, HULL_SECTION, HULL_BOW]
			and _hull_has_cabin_above(piece)
		):
			continue

		var host_x := int(piece.get("x", 0))
		var host_y := int(piece.get("y", 0))

		for offset: Vector2i in ACCESSORY_POINTS[host_id]:
			var candidate_location := Vector2i(
				host_x + offset.x,
				host_y + offset.y + 1
			)

			if (
				not _chimney_position_occupied(candidate_location)
				and not locations.has(candidate_location)
			):
				locations.append(candidate_location)

	return locations

func _hull_has_cabin_above(hull_piece: Dictionary) -> bool:
	var hull_id := int(hull_piece.get("id", -1))
	var hull_config: Dictionary = PIECE_CONFIGS.get(hull_id, {})
	if hull_config.is_empty():
		return false

	var hull_x := int(hull_piece.get("x", 0))
	var hull_y := int(hull_piece.get("y", 0))
	var hull_right := hull_x + int(hull_config["width"])
	var hull_top := hull_y + int(hull_config["height"])

	for piece in piece_instances:
		if int(piece.get("id", -1)) not in CABIN_PIECE_IDS:
			continue

		var cabin_config: Dictionary = PIECE_CONFIGS[int(piece["id"])]
		var cabin_x := int(piece.get("x", 0))
		var cabin_y := int(piece.get("y", 0))
		var cabin_right := cabin_x + int(cabin_config["width"])

		var overlaps_horizontally := cabin_x < hull_right and cabin_right > hull_x
		if cabin_y == hull_top and overlaps_horizontally:
			return true

	return false

func _chimney_position_occupied(location: Vector2i) -> bool:
	for piece in piece_instances:
		if int(piece.get("id", -1)) != CHIMNEY:
			continue

		if (
			int(piece.get("x", 0)) == location.x
			and int(piece.get("y", 0)) == location.y
		):
			return true

	return false

func _on_chimney_location_selected(location: Vector2i) -> void:
	if _chimney_position_occupied(location):
		status_label.text = "That chimney location is already occupied."
		_begin_chimney_placement()
		return

	piece_instances.append({
		"id": CHIMNEY,
		"x": location.x,
		"y": location.y,
		"flipped": false,
		"colors": []
	})

	boat_preview.set_placement_candidates(CHIMNEY, [])
	boat_preview.set_boat({"pieces": piece_instances})
	status_label.text = "Added chimney."

func _begin_chimney_placement() -> void:
	var locations := _get_open_chimney_locations()

	if locations.is_empty():
		boat_preview.set_placement_candidates(CHIMNEY, [])
		status_label.text = "No open chimney attachment locations."
		return

	boat_preview.set_placement_candidates(CHIMNEY, locations)
	status_label.text = "Select a highlighted chimney location."
