extends Control

var boat_id := ""
var load_request := HTTPRequest.new()

@onready var landing_screen: Control = $LandingScreen
@onready var boat_id_input: LineEdit = $LandingScreen/CenterContainer/VBoxContainer/BoatIdInput
@onready var message_label: Label = $LandingScreen/CenterContainer/VBoxContainer/MessageLabel
@onready var builder_view: Control = $ViewContainer/BuilderView
@onready var customize_view: Control = $ViewContainer/CustomizeView
@onready var control_view: Control = $ViewContainer/ControlView
@onready var home_button: Button = $Button

@export var server_api_base := "http://127.0.0.1:8000"
@export var web_api_base := ""

func _get_api_base() -> String:
	if OS.has_feature("web"):
		if not web_api_base.is_empty():
			return web_api_base.trim_suffix("/")

		var window = JavaScriptBridge.get_interface("window")
		var scheme := "https" if str(window.location.protocol) == "https:" else "http"
		return "%s://%s" % [scheme, str(window.location.host)]

	return server_api_base.trim_suffix("/")

func _ready() -> void:
	load_request.accept_gzip = false
	add_child(load_request)
	load_request.request_completed.connect(_on_boat_loaded)

	builder_view.boat_created.connect(_on_boat_created)
	customize_view.boat_launched.connect(_on_boat_launched)
	home_button.pressed.connect(_show_landing)

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

	_request_boat(boat_id)

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

	_request_boat(boat_id)

func _request_boat(requested_boat_id: String) -> void:
	var url := _get_api_base() + "/api/boats/" + requested_boat_id
	print("[BoatLoad] Requesting ", url)
	var error := load_request.request(url)
	if error != OK:
		push_error("[BoatLoad] Request could not start: url=%s error=%d" % [url, error])
		_show_landing("Could not start boat lookup (%d)" % error)

func _on_boat_created(new_boat_data: Dictionary) -> void:
	boat_id = str(new_boat_data.get("id", "")).to_upper()
	_route_state(new_boat_data)

func _show_builder() -> void:
	landing_screen.hide()
	customize_view.hide()
	control_view.hide()
	builder_view.clear_builder()
	home_button.show()
	builder_view.show()

func _route_state(boat_data: Dictionary) -> void:
	landing_screen.hide()
	builder_view.hide()

	var status := str(boat_data.get("status", "customizing"))
	if status == "launched":
		customize_view.hide()
		control_view.setup(boat_data)
		control_view.show()
		home_button.show()
	else:
		control_view.hide()
		customize_view.setup(boat_data)
		customize_view.show()
		home_button.show()

func _on_boat_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[BoatLoad] Request failed with result %d" % result)
		_show_landing("Could not connect to the boat server")
		return

	if response_code == 404:
		_show_landing("no boat with this id")
		return

	if response_code != 200:
		_show_landing("Boat load failed (" + str(response_code) + ")")
		return

	var response_text := body.get_string_from_utf8().strip_edges()
	var content_type := "unknown"
	for header in headers:
		if header.to_lower().begins_with("content-type:"):
			content_type = header
			break
	var parser := JSON.new()
	var parse_result := parser.parse(response_text)
	if parse_result != OK or not (parser.data is Dictionary):
		push_error(
			"[BoatLoad] Expected a JSON object from the API; content-type=%s, response-code=%d, bytes=%d, parse-error=%s, body=%s"
			% [
				content_type,
				response_code,
				body.size(),
				parser.get_error_message(),
				response_text.left(400),
			]
		)
		_show_landing("The server returned unreadable boat data. Please try again or ask an operator.")
		return

	_route_state(parser.data)

func _on_boat_launched(updated_boat_data: Dictionary) -> void:
	_route_state(updated_boat_data)


func _show_landing(message: String = "") -> void:
	builder_view.hide()
	customize_view.hide()
	control_view.hide()
	home_button.hide()

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
