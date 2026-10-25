extends Control
class_name BoatBuilderView

signal boat_created(boat_data: Dictionary)

# Piece metadata matching boat.py definitions[cite: 1]
const PIECE_CONFIGS := {
	0: {"name": "hull_bow", "width": 6, "height": 4, "category": "hull", "color": Color(0.3, 0.5, 0.7)},
	1: {"name": "hull_section", "width": 4, "height": 4, "category": "hull", "color": Color(0.35, 0.55, 0.75)},
	2: {"name": "hull_stern", "width": 4, "height": 4, "category": "hull", "color": Color(0.3, 0.5, 0.7)},
	3: {"name": "cabin", "width": 4, "height": 3, "category": "middle", "color": Color(0.8, 0.6, 0.3)},
}

const HULL_BOW := 0
const HULL_SECTION := 1
const HULL_STERN := 2
const CABIN := 3

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
@onready var boat_preview: BoatPreview2D = $CanvasPanel/BoatPreview2D

func _ready() -> void:
	add_child(submit_request)
	submit_request.request_completed.connect(_on_submit_completed)

	btn_bow.pressed.connect(func(): _add_piece(0))
	btn_section.pressed.connect(func(): _add_piece(1))
	btn_stern.pressed.connect(func(): _add_piece(2))

	btn_cabin.pressed.connect(_begin_cabin_placement)
	boat_preview.cabin_location_selected.connect(_on_cabin_location_selected)

	reset_button.pressed.connect(clear_builder)
	submit_button.pressed.connect(submit_boat)

func clear_builder() -> void:
	piece_instances.clear()
	status_label.text = ""
	boat_preview.clear_boat()

func _add_piece(id: int) -> void:
	var config: Dictionary = PIECE_CONFIGS.get(id, {})
	if config.is_empty():
		status_label.text = "Unknown piece type."
		return

	var validation_error := _get_add_error(id)
	if not validation_error.is_empty():
		status_label.text = validation_error
		return

	var x_pos := 0
	var y_pos := 0

	if id == CABIN:
		var body := _body_pieces()
		y_pos = 4

		if body.size() == 1:
			# The cabin's 4-wide connector aligns with the section's
			# two 2-wide middle attachment points.
			x_pos = int(body[0].get("x", 0))
		if (
			body.size() == 2
			and int(body[0].get("id", -1)) == HULL_STERN
			and int(body[1].get("id", -1)) == HULL_BOW
		):
			# Stern and bow each contribute one 2-wide attachment.
			# Their combined 4-wide span starts at stern.x + 2.
			x_pos = int(body[1].get("x", 0)) - 2
		var section_piece = _find_first_piece_by_type(HULL_SECTION)
		if section_piece != null:
			# Align the cabin's 4-wide connector with the section's
			# two 2-wide middle attachment points.
			x_pos = int(section_piece.get("x", 0))
		else:
			# Validation guarantees this is exactly stern followed by bow.
			# Center the cabin on the divide between them.
			var stern_piece: Dictionary = _body_pieces()[0]
			var stern_x := int(stern_piece.get("x", 0))
			var stern_width: int = PIECE_CONFIGS[HULL_STERN]["width"]
			var cabin_width: int = PIECE_CONFIGS[CABIN]["width"]
			var divide_x := stern_x + stern_width

			x_pos = divide_x - int(cabin_width / 2)


			
	# Standard snapping matching boat.py layout rules[cite: 1, 8]
	if config["category"] == "hull":
		y_pos = 0
		var current_hull_width := 0
		for p in piece_instances:
			if PIECE_CONFIGS[p["id"]]["category"] == "hull":
				current_hull_width += PIECE_CONFIGS[p["id"]]["width"]
		x_pos = current_hull_width
	else:
		y_pos = 4
		# Snap structure to the first hull section piece if available, else stack on deck[cite: 8]
		var section_piece = _find_first_piece_by_type(1)
		if section_piece != null:
			x_pos = section_piece["x"]
		else:
			x_pos = 6

	var piece := {
		"id": id,
		"x": x_pos,
		"y": y_pos,
		"flipped": false,
		"colors": []
	}
	piece_instances.append(piece)
	boat_preview.set_boat({"pieces": piece_instances})
	status_label.text = "Added " + config["name"]

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
		return "http://" + str(window.location.hostname) + ":8000"
	return "http://127.0.0.1:8000"

## Validation helpers

func _body_pieces() -> Array[Dictionary]:
	var body: Array[Dictionary] = []

	for piece in piece_instances:
		if int(piece.get("id", -1)) != CABIN:
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

	var body := _body_pieces()

	if id == CABIN:
		for piece in body:
			if int(piece.get("id", -1)) == HULL_SECTION:
				return ""

		if body.size() == 1 and int(body[0].get("id", -1)) == HULL_SECTION:
			return ""

		if (
			body.size() == 2
			and int(body[0].get("id", -1)) == HULL_STERN
			and int(body[1].get("id", -1)) == HULL_BOW
		):
			return ""

		return "A cabin needs one hull section or a stern followed by a bow."

	if id not in [HULL_BOW, HULL_SECTION, HULL_STERN]:
		return "This piece cannot be added to the boat body."

	# Treat the cabin as the last build step. Adding more body pieces after
	# it would invalidate the cabin's attachment arrangement.
	if _has_cabin():
		return "Finish the boat body before adding the cabin."

	# The first body piece may be a stern, hull section, or bow.
	if body.is_empty():
		return ""

	var last_id := int(body.back().get("id", -1))

	match last_id:
		HULL_STERN, HULL_SECTION:
			if id == HULL_SECTION or id == HULL_BOW:
				return ""
			return "A stern or hull can be followed by a hull or bow."

		HULL_BOW:
			return "The bow must be the last body piece."

	return "Invalid boat body."

func _get_open_cabin_locations() -> Array[Vector2i]:
	var body := _body_pieces()
	var candidates: Array[Vector2i] = []
	var has_section := false

	for piece in body:
		if int(piece.get("id", -1)) != HULL_SECTION:
			continue

		has_section = true
		var config: Dictionary = PIECE_CONFIGS[HULL_SECTION]
		var location := Vector2i(
			int(piece.get("x", 0)),
			int(piece.get("y", 0)) + int(config["height"])
		)

		if not _cabin_position_occupied(location):
			candidates.append(location)

	# The stern-and-bow bridge is a candidate only when there are no sections
	# and the body consists of exactly those two pieces.
	if not has_section and _is_stern_bow_body(body):
		var stern: Dictionary = body[0]
		var stern_x := int(stern.get("x", 0))
		var stern_width: int = PIECE_CONFIGS[HULL_STERN]["width"]
		var cabin_width: int = PIECE_CONFIGS[CABIN]["width"]
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
		if int(piece.get("id", -1)) != CABIN:
			continue

		if (
			int(piece.get("x", 0)) == location.x
			and int(piece.get("y", 0)) == location.y
		):
			return true

	return false

func _begin_cabin_placement() -> void:
	var locations := _get_open_cabin_locations()

	if locations.is_empty():
		status_label.text = "No open cabin attachment locations."
		boat_preview.set_cabin_candidates([])
		return

	boat_preview.set_cabin_candidates(locations)
	status_label.text = "Select a highlighted cabin location."


func _on_cabin_location_selected(location: Vector2i) -> void:
	# Recheck occupancy in case the available locations changed.
	if _cabin_position_occupied(location):
		status_label.text = "That cabin location is already occupied."
		_begin_cabin_placement()
		return

	var cabin := {
		"id": CABIN,
		"x": location.x,
		"y": location.y,
		"flipped": false,
		"colors": []
	}

	piece_instances.append(cabin)
	boat_preview.set_cabin_candidates([])
	boat_preview.set_boat({"pieces": piece_instances})
	status_label.text = "Added cabin."
