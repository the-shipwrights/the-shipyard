extends Node3D

const WS_URL := "ws://127.0.0.1:8000/ws/simulation"
const RECONNECT_DELAY := 2.0

var ws := WebSocketPeer.new()
var is_connected := false
var reconnect_timer := 0.0

# Grid layout settings
const BOATS_PER_ROW := 5
const SPACING_X := 5.0
const SPACING_Z := 5.0
var spawned_boats: Dictionary = {}

const ROTATION_SPEED := 1.8 # Radians per second
var active_rotations: Dictionary = {} # boat_id (String) -> bool

# FIX: Use @export instead of filepaths 
var mesh_constructor_scene = preload("res://packedscenes/mesh_constructor.tscn") 

func get_server_host() -> String:
	if OS.has_feature("web"):
		var window = JavaScriptBridge.get_interface("window")
		return str(window.location.hostname)
	return "127.0.0.1"

func get_api_base() -> String:
	return "http://" + get_server_host() + ":8000"

func get_ws_url(path: String) -> String:
	return "ws://" + get_server_host() + ":8000" + path

func _ready() -> void:
	_connect_to_server()

func _connect_to_server() -> void:
	print("[WS] Connecting to simulation endpoint: ", get_ws_url("/ws/simulation"))
	var err := ws.connect_to_url(get_ws_url("/ws/simulation"))
	if err != OK:
		push_error("[WS] Connection initiation failed: %d" % err)

func _process(delta: float) -> void:
	ws.poll()
	var state := ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected:
			is_connected = true
			print("[WS] Connected to FastAPI simulation socket.")

		while ws.get_available_packet_count() > 0:
			var packet := ws.get_packet()
			_handle_network_message(packet.get_string_from_utf8())

	elif state == WebSocketPeer.STATE_CLOSED:
		if is_connected:
			is_connected = false
			print("[WS] Disconnected from server (Code: %d, Reason: %s)" % [ws.get_close_code(), ws.get_close_reason()])
		
		reconnect_timer += delta
		if reconnect_timer >= RECONNECT_DELAY:
			reconnect_timer = 0.0
			print("[WS] Attempting to reconnect...")
			_connect_to_server()

	# Process active boat rotations
	for b_id in active_rotations.keys():
		if active_rotations[b_id] and spawned_boats.has(b_id):
			var boat_node: Node3D = spawned_boats[b_id]
			if is_instance_valid(boat_node):
				boat_node.rotate_y(ROTATION_SPEED * delta)


func _handle_network_message(json_text: String) -> void:
	print("[WS] Incoming message: ", json_text)
	var message = JSON.parse_string(json_text)
	if message == null or not (message is Dictionary):
		push_error("[WS] Failed to parse message JSON")
		return

	var event: String = message.get("event", "")
	if event == "initial_boats":
		var boats: Array = message.get("data", [])
		print("[WS] Syncing %d initial boats" % boats.size())
		for boat_data in boats:
			_spawn_boat(boat_data)
	elif event == "boat_launched":
		var boat_data: Dictionary = message.get("data", {})
		print("[WS] Launch event for boat: ", boat_data.get("id", ""))
		_spawn_boat(boat_data)

	elif event == "boat_control":
		var target_id: String = message.get("boat_id", "")
		var command: String = message.get("command", "")
		var active: bool = message.get("active", false)

		if command == "rotate":
			active_rotations[target_id] = active

func _spawn_boat(boat_data: Dictionary) -> void:
	var boat_id: String = boat_data.get("id", "")
	if boat_id.is_empty():
		return

	# If boat already exists, update it in place without moving its grid position
	if spawned_boats.has(boat_id):
		print("[WS] Updating existing boat: ", boat_id)
		var existing_node = spawned_boats[boat_id]
		if existing_node and is_instance_valid(existing_node):
			existing_node.build_from_data(boat_data)
			_attach_boat_label(existing_node, boat_id)
		return

	# Calculate grid coordinate based on the current boat count
	var boat_index: int = spawned_boats.size()
	var col: int = boat_index % BOATS_PER_ROW
	var row: int = boat_index / BOATS_PER_ROW

	var current_x: float = col * SPACING_X
	var current_z: float = row * SPACING_Z

	var constructor = mesh_constructor_scene.instantiate()
	add_child(constructor)
	constructor.position = Vector3(current_x, 0.0, current_z)
	constructor.build_from_data(boat_data)
	_attach_boat_label(constructor, boat_id)

	spawned_boats[boat_id] = constructor
	print("[WS] Spawned boat '%s' at grid position: (%d, %d) -> %s" % [boat_id, col, row, str(constructor.position)])

func _attach_boat_label(boat_node: Node3D, boat_id: String) -> void:
	# Avoid naming collisions if a previous label is queued for cleanup
	var old_label = boat_node.get_node_or_null("IDLabel")
	if old_label != null:
		old_label.name = "IDLabel_Old"
		old_label.queue_free()

	var label := Label3D.new()
	label.name = "IDLabel"
	label.text = boat_id
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 8
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	
	# Center the label horizontally along the hull length and float it above the mast/cabin
	label.position = Vector3(1.25, 2.6, 0.0)
	boat_node.add_child(label)
