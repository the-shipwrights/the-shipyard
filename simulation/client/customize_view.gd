extends Control

signal boat_launched(boat_data: Dictionary)

const API_BASE := "http://localhost:8000"

var boat_data: Dictionary = {}
var selected_color := "#2f7fff"
var launch_request := HTTPRequest.new()

@onready var color_picker: ColorPickerButton = $ColorPickerButton
@onready var launch_button: Button = $LaunchButton
@onready var status_label: Label = $StatusLabel
@onready var boat_label: Label = $Label
@onready var palette: GridContainer = $Palette

func _ready() -> void:
	add_child(launch_request)
	launch_request.request_completed.connect(_on_launch_completed)

	palette.connect("color_selected", Callable(self, "_on_palette_color_selected"))
	color_picker.color_changed.connect(_on_color_changed)
	launch_button.pressed.connect(launch_boat)


func setup(data: Dictionary) -> void:
	boat_data = data
	var boat_id: String = str(boat_data.get("id", ""))
	boat_label.text = "Boat #" + boat_id

	# Inspect and log piece layout as in customize.gd[cite: 26]
	var pieces: Array = boat_data.get("boat", {}).get("pieces", [])
	for piece in pieces:
		print("Piece type: ", piece.get("type_id"), " position: (", piece.get("x"), ", ", piece.get("y"), ")")

	# Initialize boat color[cite: 26]
	var hex_color: String = boat_data.get("customization", {}).get("color", "#2f7fff")
	selected_color = hex_color
	var initial_color := Color.from_string(hex_color, Color("#2f7fff"))
	color_picker.color = initial_color

	launch_button.disabled = false
	launch_button.show()
	status_label.text = ""


func _on_palette_color_selected(color: Color) -> void:
	selected_color = "#" + color.to_html(false)
	color_picker.color = color
	log_selected_color(selected_color)


func _on_color_changed(color: Color) -> void:
	selected_color = "#" + color.to_html(false)
	log_selected_color(selected_color)


func log_selected_color(color: String) -> void:
	print("Selected color: ", color)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"console.log('Selected color:', " + JSON.stringify(color) + ");",
			true
		)


func launch_boat() -> void:
	status_label.text = "Sending boat..."
	launch_button.disabled = true

	var body := JSON.stringify({"color": selected_color})
	var headers := PackedStringArray(["Content-Type: application/json"])

	var error := launch_request.request(
		API_BASE + "/api/boats/" + str(boat_data.get("id")) + "/launch",
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		status_label.text = "Could not send launch request"
		launch_button.disabled = false


func _on_launch_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	launch_button.disabled = false

	if response_code == 200:
		status_label.text = "Boat launched!"
		launch_button.hide()
		var updated_data = JSON.parse_string(body.get_string_from_utf8())
		if updated_data is Dictionary:
			boat_launched.emit(updated_data)
	elif response_code == 409:
		status_label.text = "Boat already launched!"
		boat_data["status"] = "launched"
		boat_launched.emit(boat_data)
	else:
		status_label.text = "Launch failed (" + str(response_code) + ")"
		push_error("Launch failed with code: " + str(response_code))