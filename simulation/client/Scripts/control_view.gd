extends Control

const WS_BASE := "ws://127.0.0.1:8000/ws/control/"

var boat_data: Dictionary = {}
var boat_id: String = ""
var ws := WebSocketPeer.new()
var is_connected := false

@onready var boat_preview: BoatPreview2D = $BoatPreview2D
@onready var boat_title: Label = $BoatTitle
@onready var info_label: Label = $InfoLabel
@onready var rotate_button: Button = $RotateButton
@onready var speed_button: Button = $ThrottleButton

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
	var url := WS_BASE + boat_id
	print("[ControlWS] Connecting to: ", url)
	var err := ws.connect_to_url(url)
	if err != OK:
		push_error("[ControlWS] Failed to connect: %d" % err)

func _process(_delta: float) -> void:
	ws.poll()
	var state := ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and not is_connected:
		is_connected = true
		print("[ControlWS] Connected for boat ", boat_id)

	elif state == WebSocketPeer.STATE_CLOSED and is_connected:
		is_connected = false
		print("[ControlWS] Disconnected from server")

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
		return

	var payload := {
		"command": command,
		"active": active
	}
	ws.send_text(JSON.stringify(payload))
