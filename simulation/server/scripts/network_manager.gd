# NETWORK MANAGER is responsible for establishing and maintaining
# connection to server.
#
# Network Manager will emit signals of its events

extends Node
class_name NetworkManager

# ---------------------------------------
# EXPORTS
# ---------------------------------------

## Signals
signal initial_boats_received(boats: Array)
signal boat_launched(boat_data: Dictionary)
signal boat_control_received(boat_id: String, command: String, active: bool)

## the url of the server simulation.
@export var endpoint_path := "/ws/simulation"

# ---------------------------------------
# CONSTANTS & VARIABLES
# ---------------------------------------

const RECONNECT_DELAY := 2.0

var ws := WebSocketPeer.new()
var connected := false
var reconnect_timer := 0.0

# ---------------------------------------
# METHODS
# ---------------------------------------

func _ready() -> void:
	_connect_to_server()


func _process(delta: float) -> void:
	ws.poll()

	var state := ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		connected = true
		reconnect_timer = 0.0

		while ws.get_available_packet_count() > 0:
			var packet := ws.get_packet()
			_handle_network_message(packet.get_string_from_utf8())

	elif state == WebSocketPeer.STATE_CLOSED:
		if connected:
			connected = false
			print("[WS] Disconnected from simulation server.")

		reconnect_timer += delta
		if reconnect_timer >= RECONNECT_DELAY:
			reconnect_timer = 0.0
			_connect_to_server()


func _connect_to_server() -> void:
	var error := ws.connect_to_url(_get_ws_url())
	if error != OK:
		push_error("[WS] Connection initiation failed: %d" % error)


func _get_ws_url() -> String:
	var host := "127.0.0.1"

	if OS.has_feature("web"):
		var window = JavaScriptBridge.get_interface("window")
		host = str(window.location.hostname)

	return "ws://%s:8000%s" % [host, endpoint_path]


func _handle_network_message(json_text: String) -> void:
	var message: Variant = JSON.parse_string(json_text)

	if not (message is Dictionary):
		push_error("[WS] Received invalid JSON message.")
		return

	var event: String = message.get("event", "")

	match event:
		"initial_boats":
			var boats: Variant = message.get("data", [])
			if boats is Array:
				initial_boats_received.emit(boats)

		"boat_launched":
			var boat_data: Variant = message.get("data", {})
			if boat_data is Dictionary:
				boat_launched.emit(boat_data)

		"boat_control":
			boat_control_received.emit(
				str(message.get("boat_id", "")),
				str(message.get("command", "")),
				bool(message.get("active", false))
			)
			print(
				"[WS] boat_control id=%s command=%s active=%s"
				% [
					str(message.get("boat_id", "")),
					str(message.get("command", "")),
					str(message.get("active", false))
				]
			)
