extends Control

signal boat_created(boat_data: Dictionary)

const PIECE_CATALOG := preload("res://Scripts/piece_catalog.gd")
const PIECE_CONFIGS: Dictionary = PIECE_CATALOG.PIECE_CONFIGS

const HULL_BOW := 0
const HULL_SECTION := 1
const HULL_STERN := 2
const CABIN := 3
const BIG_CABIN := 4
const CHIMNEY := 10
const SAIL := 11

const BODY_PIECE_IDS := [
	HULL_STERN,
	HULL_SECTION,
	HULL_BOW,
]

const ACCESSORY_HOST_IDS := [
	HULL_STERN,
	HULL_SECTION,
	HULL_BOW,
	CABIN,
]

const ACCESSORY_POINTS := {
	HULL_BOW: [Vector2i(1, 3)],
	HULL_SECTION: [Vector2i(1, 3)],
	HULL_STERN: [Vector2i(1, 3)],
	CABIN: [Vector2i(1, 2)],
}

const PLACEMENT_RULES := {
	CABIN: {
		"source": "body_top",
		"host_ids": [HULL_SECTION],
		"stern_bow_candidate": true,
	},
	BIG_CABIN: {
		"source": "body_top",
		"host_ids": [HULL_SECTION],
		"stern_bow_candidate": true,
	},
	CHIMNEY: {
		"source": "accessory_points",
		"host_ids": ACCESSORY_HOST_IDS,
	},
	SAIL: {
		"source": "accessory_points",
		"host_ids": ACCESSORY_HOST_IDS,
	},
}

var piece_instances: Array[Dictionary] = []
var submit_request := HTTPRequest.new()

@onready var status_label: Label = $SafeArea/Content/StatusLabel
@onready var submit_button: Button = $SafeArea/Content/ActionsContainer/SubmitButton
@onready var reset_button: Button = $SafeArea/Content/ActionsContainer/ResetButton

@onready var btn_bow: Button = $SafeArea/Content/PieceGrid/AddHullBow
@onready var btn_section: Button = $SafeArea/Content/PieceGrid/AddHullSection
@onready var btn_stern: Button = $SafeArea/Content/PieceGrid/AddHullStern
@onready var btn_cabin: Button = $SafeArea/Content/PieceGrid/AddCabin
@onready var btn_big_cabin: Button = $SafeArea/Content/PieceGrid/AddBigCabin
@onready var btn_chimney: Button = $SafeArea/Content/PieceGrid/AddChimney
@onready var btn_sail: Button = $SafeArea/Content/PieceGrid/AddSail

@onready var boat_preview: BoatPreview2D = $SafeArea/Content/CanvasPanel/BoatPreview2D

func _ready() -> void:
	add_child(submit_request)
	submit_request.request_completed.connect(_on_submit_completed)

	boat_preview.placement_selected.connect(_on_placement_selected)

	btn_bow.pressed.connect(_add_piece.bind(HULL_BOW))
	btn_section.pressed.connect(_add_piece.bind(HULL_SECTION))
	btn_stern.pressed.connect(_add_piece.bind(HULL_STERN))

	btn_cabin.pressed.connect(_begin_placement.bind(CABIN))
	btn_big_cabin.pressed.connect(_begin_placement.bind(BIG_CABIN))
	btn_chimney.pressed.connect(_begin_placement.bind(CHIMNEY))
	btn_sail.pressed.connect(_begin_placement.bind(SAIL))

	reset_button.pressed.connect(clear_builder)
	submit_button.pressed.connect(submit_boat)


func clear_builder() -> void:
	piece_instances.clear()
	status_label.text = ""
	boat_preview.set_placement_candidates(-1, [])
	boat_preview.clear_boat()

func _add_piece(piece_id: int) -> void:
	var config: Dictionary = PIECE_CONFIGS.get(piece_id, {})
	if config.is_empty():
		status_label.text = "Unknown piece type."
		return

	if piece_id not in BODY_PIECE_IDS:
		status_label.text = "Choose a highlighted placement."
		return

	var validation_error := _get_add_error(piece_id)
	if not validation_error.is_empty():
		status_label.text = validation_error
		return

	piece_instances.append({
		"id": piece_id,
		"x": _next_body_x(),
		"y": 0,
		"flipped": false,
		"colors": [],
	})
	boat_preview.set_boat({"pieces": piece_instances})
	status_label.text = "Added " + str(config["name"]) + "."


func _on_placement_selected(piece_id: int, location: Vector2i) -> void:
	var valid_locations := _get_open_locations(piece_id)
	if location not in valid_locations:
		status_label.text = "That placement is no longer available."
		_begin_placement(piece_id)
		return

	piece_instances.append({
		"id": piece_id,
		"x": location.x,
		"y": location.y,
		"flipped": false,
		"colors": [],
	})

	boat_preview.set_placement_candidates(-1, [])
	boat_preview.set_boat({"pieces": piece_instances})
	status_label.text = "Added " + str(PIECE_CONFIGS[piece_id]["name"]) + "."


func _begin_placement(piece_id: int) -> void:
	var config: Dictionary = PIECE_CONFIGS.get(piece_id, {})
	if config.is_empty() or not PLACEMENT_RULES.has(piece_id):
		status_label.text = "This piece cannot be placed here."
		return

	var locations := _get_open_locations(piece_id)
	boat_preview.set_placement_candidates(piece_id, locations)

	if locations.is_empty():
		status_label.text = "No open " + str(config["name"]) + " attachment locations."
		return

	status_label.text = "Select a highlighted " + str(config["name"]) + " location."


func _get_open_locations(piece_id: int) -> Array[Vector2i]:
	var open_locations: Array[Vector2i] = []

	for location in _get_candidate_locations(piece_id):
		if not _position_is_occupied(piece_id, location):
			open_locations.append(location)

	return open_locations


func _get_candidate_locations(piece_id: int) -> Array[Vector2i]:
	var locations: Array[Vector2i] = []
	var rule: Dictionary = PLACEMENT_RULES.get(piece_id, {})
	if rule.is_empty():
		return locations

	var host_ids: Array = rule.get("host_ids", [])

	match str(rule.get("source", "")):
		"body_top":
			for host in _body_pieces():
				var host_id := int(host.get("id", -1))
				if host_id not in host_ids:
					continue

				var host_config: Dictionary = PIECE_CONFIGS.get(host_id, {})
				if host_config.is_empty():
					continue

				var location := Vector2i(
					int(host.get("x", 0)),
					int(host.get("y", 0)) + int(host_config["height"])
				)
				_add_unique_location(locations, location)

			if bool(rule.get("stern_bow_candidate", false)):
				_add_stern_bow_candidate(piece_id, locations)

		"accessory_points":
			for host in piece_instances:
				var host_id := int(host.get("id", -1))
				if host_id not in host_ids:
					continue

				var host_x := int(host.get("x", 0))
				var host_y := int(host.get("y", 0))

				for offset: Vector2i in ACCESSORY_POINTS.get(host_id, []):
					var location := Vector2i(
						host_x + offset.x,
						host_y + offset.y + 1
					)
					_add_unique_location(locations, location)

	return locations


func _add_stern_bow_candidate(
	piece_id: int,
	locations: Array[Vector2i]
) -> void:
	var body := _body_pieces()
	if not _is_stern_bow_body(body):
		return

	var stern: Dictionary = body[0]
	var stern_id := int(stern.get("id", -1))
	var stern_config: Dictionary = PIECE_CONFIGS.get(stern_id, {})
	var piece_config: Dictionary = PIECE_CONFIGS.get(piece_id, {})
	if stern_config.is_empty() or piece_config.is_empty():
		return

	var stern_x := int(stern.get("x", 0))
	var stern_y := int(stern.get("y", 0))
	var stern_width := int(stern_config["width"])
	var piece_width := int(piece_config["width"])

	var location := Vector2i(
		stern_x + stern_width - int(piece_width / 2),
		stern_y + int(stern_config["height"])
	)
	_add_unique_location(locations, location)


func _add_unique_location(
	locations: Array[Vector2i],
	location: Vector2i
) -> void:
	if not locations.has(location):
		locations.append(location)


func _position_is_occupied(piece_id: int, location: Vector2i) -> bool:
	var candidate_config: Dictionary = PIECE_CONFIGS.get(piece_id, {})
	if candidate_config.is_empty():
		return true

	var candidate_rect := Rect2i(
		location,
		Vector2i(
			int(candidate_config["width"]),
			int(candidate_config["height"])
		)
	)

	for existing in piece_instances:
		var existing_id := int(existing.get("id", -1))
		var existing_config: Dictionary = PIECE_CONFIGS.get(existing_id, {})
		if existing_config.is_empty():
			continue

		var occupied_rect := Rect2i(
			Vector2i(
				int(existing.get("x", 0)),
				int(existing.get("y", 0))
			),
			Vector2i(
				int(existing_config["width"]),
				int(existing_config["height"])
			)
		)

		if candidate_rect.intersects(occupied_rect):
			return true

	return false


func _is_stern_bow_body(body: Array[Dictionary]) -> bool:
	return (
		body.size() == 2
		and int(body[0].get("id", -1)) == HULL_STERN
		and int(body[1].get("id", -1)) == HULL_BOW
	)


func _body_pieces() -> Array[Dictionary]:
	var body: Array[Dictionary] = []

	for piece in piece_instances:
		var piece_id := int(piece.get("id", -1))
		if piece_id in BODY_PIECE_IDS:
			body.append(piece)

	return body


func _get_add_error(piece_id: int) -> String:
	if not PIECE_CONFIGS.has(piece_id):
		return "Unknown piece type."

	if piece_id not in BODY_PIECE_IDS:
		return "This piece cannot be added to the boat body."

	var body := _body_pieces()
	if body.is_empty():
		return ""

	var last_id := int(body.back().get("id", -1))

	match last_id:
		HULL_STERN, HULL_SECTION, BIG_CABIN:
			if piece_id in [HULL_SECTION, BIG_CABIN, HULL_BOW]:
				return ""
			return "A stern, hull, or big cabin can be followed by a hull, big cabin, or bow."

		HULL_BOW:
			return "The bow must be the last body piece."

	return "Invalid boat body."


func _next_body_x() -> int:
	var x := 0

	for piece in _body_pieces():
		var piece_id := int(piece.get("id", -1))
		var config: Dictionary = PIECE_CONFIGS.get(piece_id, {})
		if not config.is_empty():
			x += int(config["width"])

	return x


func submit_boat() -> void:
	if piece_instances.is_empty():
		status_label.text = "Add at least one piece before submitting."
		return

	status_label.text = "Registering boat on backend..."
	submit_button.disabled = true

	var payload := {
		"pieces": piece_instances,
		"edges": [],
	}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := _get_api_base() + "/api/boats"
	var error := submit_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		status_label.text = "Failed to send request."
		submit_button.disabled = false

func _on_submit_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	submit_button.disabled = false

	if response_code != 200 and response_code != 201:
		status_label.text = "Submission failed (" + str(response_code) + ")"
		push_error("Backend rejected boat: " + body.get_string_from_utf8())
		return

	var response: Variant = JSON.parse_string(body.get_string_from_utf8())
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
