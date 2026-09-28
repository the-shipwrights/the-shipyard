extends Node3D

# Use explicit IPv4 loopback to avoid DNS/IPv6 mismatch with uvicorn
const WS_URL := "ws://127.0.0.1:8000/ws/simulation"

var ws := WebSocketPeer.new()
var is_connected := false
var spawn_offset_x := 0.0

func _ready() -> void:
	print("Connecting to backend simulation socket: ", WS_URL)
	var err := ws.connect_to_url(WS_URL)
	if err != OK:
		push_error("Failed to initiate WebSocket connection: %d" % err)


func _process(_delta: float) -> void:
	# Godot requires continuous polling to process network frames
	ws.poll()

	var state := ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected:
			is_connected = true
			print("Connected to FastAPI simulation WebSocket!")

		# Process all available incoming messages in this frame
		while ws.get_available_packet_count() > 0:
			var packet := ws.get_packet()
			var text := packet.get_string_from_utf8()
			_handle_network_message(text)

	elif state == WebSocketPeer.STATE_CLOSED:
		if is_connected:
			is_connected = false
			var code := ws.get_close_code()
			var reason := ws.get_close_reason()
			print("WebSocket disconnected. Code: %d, Reason: %s" % [code, reason])


func _handle_network_message(json_text: String) -> void:
	var message = JSON.parse_string(json_text)
	if message == null or not (message is Dictionary):
		return

	if message.get("event") == "boat_launched":
		var boat_data: Dictionary = message.get("data", {})
		var boat_id: String = boat_data.get("id", "UNKNOWN")
		var color_hex: String = boat_data.get("customization", {}).get("color", "#ffffff")
		
		print("Received launched boat: %s (Color: %s)" % [boat_id, color_hex])
		
		# Spawn representation at offset position
		var spawn_pos := Vector3(spawn_offset_x, 0.0, 0.0)
		create_boat_cube(boat_id, color_hex, spawn_pos)
		spawn_offset_x += 3.0


func create_boat_cube(boat_id: String, hex_color: String, spawn_position: Vector3) -> Node3D:
	var boat_root := Node3D.new()
	boat_root.name = "Boat_" + boat_id
	boat_root.position = spawn_position

	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(2.0, 1.0, 3.0)
	mesh_instance.mesh = box_mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color.from_string(hex_color, Color.WHITE)
	mesh_instance.material_override = material
	boat_root.add_child(mesh_instance)

	var label := Label3D.new()
	label.text = boat_id
	label.position = Vector3(0.0, 1.3, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 8
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	boat_root.add_child(label)

	add_child(boat_root)
	return boat_root