extends Control

@export var server_ws_base := "ws://127.0.0.1:8000"
@export var web_ws_base := ""

const RECONNECT_DELAY := 2.0

var reconnect_timer := 0.0
var pending_controls: Dictionary = {}

var boat_data: Dictionary = {}
var boat_id: String = ""
var ws := WebSocketPeer.new()
var is_connected := false

@onready var boat_preview: BoatPreview2D = $SafeArea/Content/CanvasPanel/BoatPreview2D
@onready var boat_title: Label = $SafeArea/Content/BoatTitle
@onready var info_label: Label = $SafeArea/Content/InfoLabel
@onready var rotate_button: Button = $SafeArea/Content/RotateButton
@onready var speed_button: Button = $SafeArea/Content/ThrottleButton

func _ready() -> void:
	speed_button.button_down.connect(_on_speed_pressed)
	speed_button.button_up.connect(_on_speed_released)
	rotate_button.button_down.connect(_on_rotate_pressed)
	rotate_button.button_up.connect(_on_rotate_released)

func setup(data: Dictionary) -> void:
	boat_data = data
	boat_preview.set_boat(data)

	boat_id = str(boat_data.get("id", "")).to_upper()
	boat_title.text = "Piloting Boat #" + boat_id
	info_label.text = "Hold the button below to turn your boat in the archipelago."
	_connect_to_control_socket()

func _connect_to_control_socket() -> void:
	if boat_id.is_empty():
		return

	if ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		return

	var url := _get_control_ws_base() + "/ws/control/" + boat_id
	print("[ControlWS] Connecting to: ", url)
	var err := ws.connect_to_url(url)
	if err != OK:
		push_error("[ControlWS] Failed to connect: %d" % err)

func _process(delta: float) -> void:
	ws.poll()
	var state := ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		reconnect_timer = 0.0

		if not is_connected:
			is_connected = true
			print("[ControlWS] Connected for boat ", boat_id)

		_flush_pending_controls()
	elif state == WebSocketPeer.STATE_CLOSED:
		if is_connected:
			is_connected = false
			print("[ControlWS] Disconnected from server.")

		reconnect_timer += delta
		if reconnect_timer >= RECONNECT_DELAY:
			reconnect_timer = 0.0
			_connect_to_control_socket()

func _on_rotate_pressed() -> void:
	_send_control_command("rotate", true)

func _on_rotate_released() -> void:
	_send_control_command("rotate", false)

func _on_speed_pressed() -> void:
	_send_control_command("accelerate", true)

func _on_speed_released() -> void:
	_send_control_command("accelerate", false)

func _send_control_command(command: String, active: bool) -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		# Keep the most recent state. For example, a quick press and release
		# while connecting will leave this set to false.
		pending_controls[command] = active
		return

	var payload := {
		"command": command,
		"active": active
	}

	var err := ws.send_text(JSON.stringify(payload))
	if err != OK:
		pending_controls[command] = active
		push_warning("[ControlWS] Send failed; queued command: %s" % command)


func _flush_pending_controls() -> void:
	for command in pending_controls.keys():
		var payload := {
			"command": command,
			"active": bool(pending_controls[command])
		}

		var err := ws.send_text(JSON.stringify(payload))
		if err != OK:
			return

		pending_controls.erase(command)

func _get_control_ws_base() -> String:
	if OS.has_feature("web"):
		# Set web_ws_base explicitly for production deployments, for example:
		# wss://boats.example.com
		if not web_ws_base.is_empty():
			return web_ws_base.trim_suffix("/")

		var window = JavaScriptBridge.get_interface("window")
		var scheme := "wss" if str(window.location.protocol) == "https:" else "ws"
		return "%s://%s:8000" % [scheme, str(window.location.hostname)]

	# For a native mobile build, set this to the backend's reachable LAN address.
	return server_ws_base.trim_suffix("/")
