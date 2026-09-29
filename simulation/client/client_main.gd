extends Control

const API_BASE := "http://localhost:8000"

var boat_id := ""
var load_request := HTTPRequest.new()

@onready var no_boat_screen: Control = $NoBoatScreen
@onready var no_boat_label: Label = $NoBoatScreen/CenterContainer/NoBoatLabel
@onready var customize_view: Control = $ViewContainer/CustomizeView
@onready var control_view: Control = $ViewContainer/ControlView

func _ready() -> void:
	add_child(load_request)
	load_request.request_completed.connect(_on_boat_loaded)

	customize_view.boat_launched.connect(_on_boat_launched)

	boat_id = get_boat_id_from_query()
	if boat_id.is_empty():
		_show_error("No boat ID supplied")
		push_error("No boat ID was supplied")
		return

	var error := load_request.request(API_BASE + "/api/boats/" + boat_id)
	if error != OK:
		_show_error("Could not connect to the boat server")
		push_error("Could not start boat request")


func _on_boat_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 404:
		_show_error("No boat found")
		return

	if response_code != 200:
		_show_error("Boat load failed (" + str(response_code) + ")")
		push_error("Boat load failed with status: " + str(response_code))
		return

	var boat_data = JSON.parse_string(body.get_string_from_utf8())
	if boat_data == null or not (boat_data is Dictionary):
		_show_error("Invalid response from server")
		push_error("Invalid JSON received")
		return

	_route_state(boat_data)


func _route_state(boat_data: Dictionary) -> void:
	no_boat_screen.hide()
	var status: String = boat_data.get("status", "customizing")

	if status == "launched":
		customize_view.hide()
		control_view.setup(boat_data)
		control_view.show()
	else:
		control_view.hide()
		customize_view.setup(boat_data)
		customize_view.show()


func _on_boat_launched(updated_boat_data: Dictionary) -> void:
	_route_state(updated_boat_data)


func _show_error(msg: String) -> void:
	customize_view.hide()
	control_view.hide()
	no_boat_label.text = msg
	no_boat_screen.show()


func get_boat_id_from_query() -> String:
	if not OS.has_feature("web"):
		return "ABCD"

	var window = JavaScriptBridge.get_interface("window")
	var query := str(window.location.search).trim_prefix("?")

	for parameter in query.split("&"):
		var parts := parameter.split("=", true, 1)
		if parts.size() == 2 and parts[0] == "boat":
			return parts[1].uri_decode().to_upper()

	return ""
