extends Control

signal boat_created(boat_data: Dictionary)

const SCALE_PREVIEW := 0.6  # Scales Boat.py coordinates into the preview panel
const CANVAS_ORIGIN := Vector2(20, 240) # Bottom-left baseline in the canvas

# Piece metadata matching Boat.py definitions[cite: 1]
const PIECE_CONFIGS := {
	0: {"name": "hull_front", "width": 150, "height": 100, "category": "hull", "color": Color(0.3, 0.5, 0.7)},
	1: {"name": "hull_middle", "width": 100, "height": 100, "category": "hull", "color": Color(0.35, 0.55, 0.75)},
	2: {"name": "hull_back", "width": 150, "height": 100, "category": "hull", "color": Color(0.3, 0.5, 0.7)},
	3: {"name": "cabin", "width": 100, "height": 100, "category": "structure", "color": Color(0.8, 0.6, 0.3)},
	5: {"name": "tent", "width": 100, "height": 80, "category": "structure", "color": Color(0.4, 0.7, 0.4)},
	6: {"name": "flag", "width": 10, "height": 80, "category": "structure", "color": Color(0.9, 0.2, 0.2)},
}

var placed_pieces: Array[Dictionary] = []
var next_piece_id: int = 0
var submit_request := HTTPRequest.new()

@onready var pieces_container: Control = $CanvasPanel/PiecesContainer
@onready var status_label: Label = $StatusLabel
@onready var submit_button: Button = $ActionsContainer/SubmitButton
@onready var reset_button: Button = $ActionsContainer/ResetButton

# Palette buttons
@onready var btn_front: Button = $PaletteGrid/AddHullFront
@onready var btn_mid: Button = $PaletteGrid/AddHullMid
@onready var btn_back: Button = $PaletteGrid/AddHullBack
@onready var btn_cabin: Button = $PaletteGrid/AddCabin
@onready var btn_tent: Button = $PaletteGrid/AddTent
@onready var btn_flag: Button = $PaletteGrid/AddFlag

func _ready() -> void:
	add_child(submit_request)
	submit_request.request_completed.connect(_on_submit_completed)

	btn_front.pressed.connect(func(): _add_piece(0))
	btn_mid.pressed.connect(func(): _add_piece(1))
	btn_back.pressed.connect(func(): _add_piece(2))
	btn_cabin.pressed.connect(func(): _add_piece(3))
	btn_tent.pressed.connect(func(): _add_piece(5))
	btn_flag.pressed.connect(func(): _add_piece(6))

	reset_button.pressed.connect(clear_builder)
	submit_button.pressed.connect(submit_boat)

func clear_builder() -> void:
	placed_pieces.clear()
	next_piece_id = 0
	status_label.text = ""
	for child in pieces_container.get_children():
		child.queue_free()

func _add_piece(type_id: int) -> void:
	var config: Dictionary = PIECE_CONFIGS.get(type_id, {})
	if config.is_empty():
		return

	var x_pos := 0
	var y_pos := 0

	# Standard snapping matching Boat.py layout rules[cite: 1, 8]
	if config["category"] == "hull":
		y_pos = 0
		var current_hull_width := 0
		for p in placed_pieces:
			if PIECE_CONFIGS[p["type_id"]]["category"] == "hull":
				current_hull_width += PIECE_CONFIGS[p["type_id"]]["width"]
		x_pos = current_hull_width
	else:
		y_pos = 100
		# Snap structure to the first hull middle piece if available, else stack on deck[cite: 8]
		var mid_piece = _find_first_piece_by_type(1)
		if mid_piece != null:
			x_pos = mid_piece["x"]
		else:
			x_pos = 150

	var piece := {
		"id": next_piece_id,
		"type_id": type_id,
		"x": x_pos,
		"y": y_pos,
		"flipped": false,
		"colors": []
	}
	next_piece_id += 1
	placed_pieces.append(piece)

	_render_preview_piece(piece, config)
	status_label.text = "Added " + config["name"]

func _find_first_piece_by_type(target_type_id: int):
	for p in placed_pieces:
		if p["type_id"] == target_type_id:
			return p
	return null

func _render_preview_piece(piece: Dictionary, config: Dictionary) -> void:
	var rect := ColorRect.new()
	rect.name = "Piece_" + str(piece["id"])
	rect.color = config["color"]

	var width: float = float(config["width"]) * SCALE_PREVIEW
	var height: float = float(config["height"]) * SCALE_PREVIEW
	rect.size = Vector2(width, height)

	# Invert Godot GUI Y axis to match Boat.py bottom-up coordinates[cite: 1]
	var screen_x: float = CANVAS_ORIGIN.x + (float(piece["x"]) * SCALE_PREVIEW)
	var screen_y: float = CANVAS_ORIGIN.y - (float(piece["y"]) * SCALE_PREVIEW) - height

	rect.position = Vector2(screen_x, screen_y)
	pieces_container.add_child(rect)

func submit_boat() -> void:
	if placed_pieces.is_empty():
		status_label.text = "Add at least one piece before submitting."
		return

	status_label.text = "Registering boat on backend..."
	submit_button.disabled = true

	# Match payload expected by FastAPI backend and submit_boat.py[cite: 2, 8]
	var payload := {
		"pieces": placed_pieces,
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

	if response_code == 200 or response_code == 201:
		var response = JSON.parse_string(body.get_string_from_utf8())
		if response is Dictionary:
			status_label.text = "Boat created: " + str(response.get("id", ""))
			boat_created.emit(response)
	else:
		status_label.text = "Submission failed (" + str(response_code) + ")"
		push_error("Backend rejected boat: " + body.get_string_from_utf8())

func _get_api_base() -> String:
	if OS.has_feature("web"):
		var window = JavaScriptBridge.get_interface("window")
		return "http://" + str(window.location.hostname) + ":8000"
	return "http://127.0.0.1:8000"