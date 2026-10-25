extends Node3D
class_name MeshConstructor

# Converts Boat.py pixel dimensions (e.g., width 100) to Godot 3D meters (1.0m)
const SCALE_FACTOR := 0.25

var use_custom_models := false # Toggle this to true when final models are ready

var boat_footprint := Vector3.ZERO

# func _ready() -> void:

## Build directly from a provided data dictionary
func build_from_data(data: Dictionary) -> void:
	_clear_existing_meshes()

	var boat_id := str(data.get("id", "<unknown>"))
	var customization: Dictionary = data.get("customization", {})

	var primary_hex := str(customization.get("primary", "#2f7fff"))
	var secondary_hex := str(customization.get("secondary", "#ffffff"))
	var accent_hex := str(customization.get("accent", "#ff8800"))

	var primary_color := Color.from_string(primary_hex, Color("#2f7fff"))
	var secondary_color := Color.from_string(secondary_hex, Color.WHITE)
	var accent_color := Color.from_string(accent_hex, Color("#ff8800"))

	print(
		"[Boat %s] colors: primary=%s secondary=%s accent=%s"
		% [boat_id, primary_hex, secondary_hex, accent_hex]
	)

	var primary_material := StandardMaterial3D.new()
	primary_material.albedo_color = primary_color

	var secondary_material := StandardMaterial3D.new()
	secondary_material.albedo_color = secondary_color

	var accent_material := StandardMaterial3D.new()
	accent_material.albedo_color = accent_color

	var boat_data: Dictionary = data.get("boat", {})
	var pieces: Array = boat_data.get("pieces", [])

	var max_x := 0.0
	var max_y := 0.0
	var max_depth := 0.0

	for piece in pieces:
		if not (piece is Dictionary):
			continue

		var piece_x := float(piece.get("x", 0)) * SCALE_FACTOR
		var piece_y := float(piece.get("y", 0)) * SCALE_FACTOR
		
		# Coloring
		var piece_id := int(piece.get("id", -1))
		var material := primary_material
		match piece_id:
			3, 4:
				material = secondary_material
			11:
				material = accent_material

		var piece_node := _create_piece_node(piece, material)

		if piece_node == null:
			continue

		var piece_width := float(piece_node.get_meta("width", 1.0))
		var piece_height := float(piece_node.get_meta("height", 1.0))
		var piece_depth := float(piece_node.get_meta("depth", 1.0))

		max_x = maxf(max_x, piece_x + piece_width)
		max_y = maxf(max_y, piece_y + piece_height)
		max_depth = maxf(max_depth, piece_depth)

		add_child(piece_node)

	boat_footprint = Vector3(max_x, max_y, max_depth)

func _create_color_placeholder(
	label_text: String,
	color: Color,
	placeholder_position: Vector3
) -> void:
	var placeholder := MeshInstance3D.new()
	placeholder.name = label_text + "ColorPlaceholder"

	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	placeholder.mesh = sphere
	placeholder.position = placeholder_position

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	placeholder.material_override = material

	add_child(placeholder)

	var label := Label3D.new()
	label.text = label_text
	label.position = Vector3(0.0, 0.35, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 20
	label.outline_size = 4
	placeholder.add_child(label)

func _clear_existing_meshes() -> void:
	# Removes existing pieces so the constructor can be reused/updated safely
	for child in get_children():
		child.queue_free()

func _create_piece_node(piece: Dictionary, base_material: StandardMaterial3D) -> Node3D:
	var id: int = piece.get("id", -1)
	var pos_x: float = float(piece.get("x", 0)) * SCALE_FACTOR
	var pos_y: float = float(piece.get("y", 0)) * SCALE_FACTOR
	var flipped: bool = piece.get("flipped", false)
	
	var piece_node: Node3D
	
	if use_custom_models:
		# FUTURE IMPLEMENTATION: Load custom scenes based on piece id
		# Example:
		# piece_node = load("res://models/pieces/piece_%d.tscn" % id).instantiate()
		pass
	else:
		# CURRENT IMPLEMENTATION: Procedural primitive shapes based on boat.py[cite: 1]
		piece_node = _generate_primitive(id, base_material)
	
	if not piece_node:
		return null
		
	# Godot primitives are centered. We offset by half the width/height 
	# to match the bottom-left coordinate system used in Boat.py.
	var visual_width := 1.0 # Default fallback
	var visual_height := 1.0
	
	if piece_node.has_meta("width"): visual_width = piece_node.get_meta("width")
	if piece_node.has_meta("height"): visual_height = piece_node.get_meta("height")
	
	piece_node.position = Vector3(
		pos_x + (visual_width / 2.0),
		pos_y + (visual_height / 2.0),
		0.0
	)
	
	# Apply flipping
	if flipped:
		piece_node.scale.x = -1.0
		
	return piece_node

func _generate_primitive(id: int, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh: Mesh
	var w := 1.0
	var h := 1.0
	var d := 1.5
	
	# Mapping based on PieceType definitions in boat.py[cite: 1]
	match id:
		0: # HULL_BOW (w=6, h=4)
			w = 1.5; h = 1.0; d = 1.5
			mesh = PrismMesh.new() # Using prism for angled hull
			mesh.size = Vector3(w, h, d)
			mesh.left_to_right = 0.0
			mesh_instance.rotation_degrees.x = 180.0
		1: # HULL_SECTION (w=4, h=4)
			w = 1.0; h = 1.0; d = 1.5
			mesh = BoxMesh.new()
			mesh.size = Vector3(w, h, d)
		2: # HULL_STERN (w=4, h=4)
			w = 1.0; h = 1.0; d = 1.5
			mesh = PrismMesh.new() # Using prism for angled hull
			mesh.size = Vector3(w, h, d)
			mesh.left_to_right = 1.0
			mesh_instance.rotation_degrees.x = 180.0
		3: # CABIN (w=4, h=3)
			w = 1.0; h = 0.75; d = 1.0
			mesh = BoxMesh.new()
			mesh.size = Vector3(w, h, d)
		4: # BIG_CABIN (4 × 6 grid units)
			w = 1.0
			h = 1.5
			d = 1.0
			mesh = BoxMesh.new()
			mesh.size = Vector3(w, h, d)
		11: # CHIMNEY
			w = SCALE_FACTOR
			h = 4.0 * SCALE_FACTOR
			d = SCALE_FACTOR

			var chimney_mesh := CylinderMesh.new()
			chimney_mesh.top_radius = w * 0.4
			chimney_mesh.bottom_radius = w * 0.45
			chimney_mesh.height = h
			chimney_mesh.radial_segments = 8
			mesh = chimney_mesh
		_:
			push_warning("Unknown piece type: ", id)
			return null
			
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	
	# Store dimensions as metadata for positioning math
	mesh_instance.set_meta("width", w)
	mesh_instance.set_meta("height", h)
	mesh_instance.set_meta("depth", d)
	
	return mesh_instance
