extends Node

const API_BASE := "http://localhost:8000"

var boat_id := ""
var request := HTTPRequest.new()


func _ready():
	add_child(request)
	request.request_completed.connect(_on_boat_request_completed)

	boat_id = get_boat_id_from_query()

	if boat_id.is_empty():
		push_error("No boat ID was supplied")
		return

	var error := request.request(
		API_BASE + "/api/boats/" + boat_id
	)

	if error != OK:
		push_error("Could not start boat request")


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
	if response_code != 200:
		push_error("Boat request failed: " + str(response_code))
		return

	var data = JSON.parse_string(
		body.get_string_from_utf8()
	)

	if data == null:
		push_error("Invalid JSON received")
		return

	print(data)
	# Render data["boat"] here.
	# Use data["customization"]["color"] for the selected color.

func save_color(color: String):
	var body := JSON.stringify({
		"color": color
	})

	var headers := PackedStringArray([
        "Content-Type: application/json"
	])

	request.request(
		API_BASE + "/api/boats/" + boat_id,
		headers,
		HTTPClient.METHOD_PATCH,
		body
	)

func launch_boat():
	request.request(
		API_BASE + "/api/boats/" + boat_id + "/launch",
		PackedStringArray(),
		HTTPClient.METHOD_POST
	)
