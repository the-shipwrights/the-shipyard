extends Node3D
class_name MeshConstructor

# Converts Boat.py pixel dimensions (e.g., width 100) to Godot 3D meters (1.0m)
const SCALE_FACTOR := 0.25

var use_custom_models := false # Toggle this to true when final models are ready

# func _ready() -> void:

## Build directly from a provided data dictionary
func build_from_data(data: Dictionary) -> void:
	_clear_existing_meshes()
	
	# Extract customization color[cite: 2]
	var hex_color: String = data.get("customization", {}).get("color", "#2f7fff")
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color.from_string(hex_color, Color.WHITE)
	
	var boat_data: Dictionary = data.get("boat", {})
	var pieces: Array = boat_data.get("pieces", [])
	
	for piece in pieces:
		var piece_node := _create_piece_node(piece, base_material)
		if piece_node:
			add_child(piece_node)

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
		
	# Apply piece-specific colors if provided in the struct[cite: 1]
	var piece_colors: Array = piece.get("colors", [])
	if piece_colors.size() > 0 and piece_node is MeshInstance3D:
		var custom_mat := StandardMaterial3D.new()
		custom_mat.albedo_color = Color.from_string(piece_colors[0], Color.WHITE)
		piece_node.material_override = custom_mat
		
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
		0: # HULL_FRONT (w=6, h=4)
			w = 1.5; h = 1.0; d = 1.5
			mesh = PrismMesh.new() # Using prism for angled hull
			mesh.size = Vector3(w, h, d)
			mesh.left_to_right = 1.0
			mesh_instance.rotation_degrees.x = 180.0
		1: # HULL_MIDDLE (w=4, h=4)
			w = 1.0; h = 1.0; d = 1.5
			mesh = BoxMesh.new()
			mesh.size = Vector3(w, h, d)
		2: # HULL_BACK (w=4, h=4)
			w = 1.0; h = 1.0; d = 1.5
			mesh = PrismMesh.new() # Using prism for angled hull
			mesh.size = Vector3(w, h, d)
			mesh.left_to_right = 0.0
			mesh_instance.rotation_degrees.x = 180.0
		3: # CABIN (w=4, h=3)
			w = 1.0; h = 0.75; d = 1.0
			mesh = BoxMesh.new()
			mesh.size = Vector3(w, h, d)
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
