extends Control

var boat_id := ""
var load_request := HTTPRequest.new()

@onready var landing_screen: Control = $LandingScreen
@onready var boat_id_input: LineEdit = $LandingScreen/CenterContainer/VBoxContainer/BoatIdInput
@onready var message_label: Label = $LandingScreen/CenterContainer/VBoxContainer/MessageLabel
@onready var builder_view: Control = $ViewContainer/BuilderView
@onready var customize_view: Control = $ViewContainer/CustomizeView
@onready var control_view: Control = $ViewContainer/ControlView

func get_server_host() -> String:
	if OS.has_feature("web"):
		var window = JavaScriptBridge.get_interface("window")
		return str(window.location.hostname)
	return "127.0.0.1"

func get_api_base() -> String:
	return "http://" + get_server_host() + ":8000"

func _ready() -> void:
	add_child(load_request)
	load_request.request_completed.connect(_on_boat_loaded)

	builder_view.boat_created.connect(_on_boat_created)
	customize_view.boat_launched.connect(_on_boat_launched)

	$LandingScreen/CenterContainer/VBoxContainer/LoadBoatButton.pressed.connect(_submit_boat_id)
	$LandingScreen/CenterContainer/VBoxContainer/BuilderButton.pressed.connect(_show_builder)
	boat_id_input.text_submitted.connect(_submit_boat_id)

	boat_id = get_boat_id_from_query()
	if boat_id.is_empty():
		_show_landing()
		return

	if not _is_valid_boat_id(boat_id):
		_show_landing("no boat with this id")
		return

	var error := load_request.request(get_api_base() + "/api/boats/" + boat_id)
	if error != OK:
		_show_landing("Could not connect to the boat server")

func _is_valid_boat_id(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Z]{4}$")
	return regex.search(value.to_upper()) != null


func _submit_boat_id(_submitted_text: String = "") -> void:
	boat_id = boat_id_input.text.strip_edges().to_upper()
	boat_id_input.text = boat_id

	if not _is_valid_boat_id(boat_id):
		_show_landing("Enter a 4-letter boat ID")
		return

	var error := load_request.request(get_api_base() + "/api/boats/" + boat_id)
	if error != OK:
		_show_landing("Could not connect to the boat server")

func _on_boat_created(new_boat_data: Dictionary) -> void:
	boat_id = str(new_boat_data.get("id", "")).to_upper()
	_route_state(new_boat_data)

func _show_builder() -> void:
	landing_screen.hide()
	customize_view.hide()
	control_view.hide()
	builder_view.clear_builder()
	builder_view.show()

func _route_state(boat_data: Dictionary) -> void:
	landing_screen.hide()
	builder_view.hide()

	var status := str(boat_data.get("status", "customizing"))
	if status == "launched":
		customize_view.hide()
		control_view.setup(boat_data)
		control_view.show()
	else:
		control_view.hide()
		customize_view.setup(boat_data)
		customize_view.show()

func _on_boat_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 404:
		_show_landing("no boat with this id")
		return

	if response_code != 200:
		_show_landing("Boat load failed (" + str(response_code) + ")")
		return

	var boat_data = JSON.parse_string(body.get_string_from_utf8())
	if boat_data == null or not (boat_data is Dictionary):
		_show_landing("Invalid response from server")
		return

	_route_state(boat_data)

func _on_boat_launched(updated_boat_data: Dictionary) -> void:
	_route_state(updated_boat_data)


func _show_landing(message: String = "") -> void:
	builder_view.hide()
	customize_view.hide()
	control_view.hide()

	message_label.text = message
	message_label.visible = not message.is_empty()
	landing_screen.show()


func get_boat_id_from_query() -> String:
	var query := ""
	if OS.has_feature("web"):
		var window = JavaScriptBridge.get_interface("window")
		query = str(window.location.search).trim_prefix("?")
	else:
		return ""

	for parameter in query.split("&"):
		var parts := parameter.split("=", true, 1)
		if parts.size() == 2 and parts[0] == "boat":
			return parts[1].uri_decode().to_upper()

	return ""
