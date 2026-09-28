extends Control

const API_BASE := "http://localhost:8000"

var boat_id := ""
var selected_color := "#000000"
var load_request := HTTPRequest.new()
var launch_request := HTTPRequest.new()

@onready var color_picker: ColorPickerButton = $ColorPickerButton
@onready var launch_button: Button = $LaunchButton
@onready var status_label: Label = $StatusLabel
@onready var boat_label: Label = $Label
@onready var palette: GridContainer = $Palette
@onready var no_boat_screen: Control = $NoBoatScreen
@onready var no_boat_label: Label = $NoBoatScreen/CenterContainer/NoBoatLabel

func _ready() -> void:
	add_child(load_request)
	add_child(launch_request)
	
	load_request.request_completed.connect(_on_boat_loaded)
	launch_request.request_completed.connect(_on_launch_completed)

	palette.connect("color_selected", Callable(self, "_on_palette_color_selected"))
	color_picker.color_changed.connect(_on_color_changed)
	launch_button.pressed.connect(launch_boat)

	boat_id = get_boat_id_from_query()

	if boat_id.is_empty():
		show_no_boat_screen("No boat ID supplied")
		push_error("No boat ID was supplied")
		return

	boat_label.text = "Boat #" + boat_id

	var error := load_request.request(API_BASE + "/api/boats/" + boat_id)
	if error != OK:
		show_no_boat_screen("Could not connect to the boat server")
		push_error("Could not start boat request")

func show_no_boat_screen(message: String) -> void:
	no_boat_label.text = message
	no_boat_screen.show()

	palette.hide()
	color_picker.hide()
	launch_button.hide()
	status_label.hide()
	boat_label.hide()


func show_customizer_screen() -> void:
	no_boat_screen.hide()

	palette.show()
	launch_button.show()
	status_label.show()
	boat_label.show()

	# The color picker is intentionally hidden in the current UI.
	color_picker.hide()

func _on_palette_color_selected(color: Color) -> void:
	selected_color = "#" + color.to_html(false)
	log_selected_color(selected_color)


func _on_color_changed(color: Color) -> void:
	selected_color = "#" + color.to_html(false)
	log_selected_color(selected_color)

func log_selected_color(color: String):
	print("Selected color: ", color)

	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"console.log('Selected color:', " + JSON.stringify(color) + ");",
			true
		)

func _on_boat_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 404:
		show_no_boat_screen("No boat found")
		return

	if response_code != 200:
		push_error("Boat load failed with status: " + str(response_code))
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		push_error("Invalid JSON received")
		return

	var server_color := Color(str(data["customization"]["color"]))
	color_picker.color = server_color
	selected_color = "#" + server_color.to_html(false)

func get_boat_id_from_query() -> String:
	if not OS.has_feature("web"):
		return "DEMO"

	var window = JavaScriptBridge.get_interface("window")
	var query := str(window.location.search).trim_prefix("?")

	for parameter in query.split("&"):
		var parts := parameter.split("=", true, 1)

		if parts.size() == 2 and parts[0] == "boat":
			return parts[1].uri_decode().to_upper()

	return ""

func _on_boat_request_completed(
	result,
	response_code,
	headers,
	body
):
	if response_code == 404:
		show_no_boat_screen("No boat found")
		return
	
	if response_code != 200:
		push_error("Boat request failed: " + str(response_code))
		return

	var data = JSON.parse_string(
		body.get_string_from_utf8()
	)

	if data == null:
		push_error("Invalid JSON received")
		return

	var server_color := Color(
		str(data["customization"]["color"])
	)

	color_picker.color = server_color
	selected_color = "#" + server_color.to_html(false)

	var boat_data = data["boat"]

	for piece_data in boat_data["pieces"]:
		print(
			"Piece type: ",
			piece_data["type_id"],
			" position: ",
			piece_data["x"],
			", ",
			piece_data["y"]
		)

	# Render boat_data["pieces"] here.



func launch_boat() -> void:
	status_label.text = "Sending boat..."
	launch_button.disabled = true

	var body := JSON.stringify({"color": selected_color})
	var headers := PackedStringArray(["Content-Type: application/json"])

	var error := launch_request.request(
		API_BASE + "/api/boats/" + boat_id + "/launch",
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
	else:
		status_label.text = "Launch failed (" + str(response_code) + ")"
		push_error("Launch failed with code: " + str(response_code))
