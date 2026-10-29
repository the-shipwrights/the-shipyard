@tool
extends Node3D
class_name MeshConstructor

const SCALE_FACTOR := 0.25

# omg my eyes

@export var bow: PackedScene = preload(
	"res://packedscenes/boat_components/hull_bow.tscn"
)

@export var section: PackedScene = preload(
	"res://packedscenes/boat_components/hull_section.tscn"
)

@export var stern: PackedScene = preload(
	"res://packedscenes/boat_components/hull_stern.tscn"
)

@export var cabin: PackedScene = preload(
	"res://packedscenes/boat_components/cabin.tscn"
)

@export var sail: PackedScene = preload(
	"res://packedscenes/boat_components/sail.tscn"
)

@export var chimney: PackedScene = preload(
	"res://packedscenes/boat_components/chimney.tscn"
)


const HULL_BOW_SCENE: PackedScene = preload(
	"res://packedscenes/boat_components/hull_bow.tscn"
)
const HULL_SECTION_SCENE: PackedScene = preload(
	"res://packedscenes/boat_components/hull_section.tscn"
)
const HULL_STERN_SCENE: PackedScene = preload(
	"res://packedscenes/boat_components/hull_stern.tscn"
)
const CABIN_SCENE: PackedScene = preload(
	"res://packedscenes/boat_components/cabin.tscn"
)

const SAIL_SCENE: PackedScene = preload(
	"res://packedscenes/boat_components/sail.tscn"
)

const CHIMNEY_SCENE: PackedScene = preload(
	"res://packedscenes/boat_components/chimney.tscn"
)

var _last_data: Dictionary = {}

@export var show_editor_preview := false:
	set(value):
		show_editor_preview = value
		if Engine.is_editor_hint() and is_inside_tree():
			_refresh_editor_preview()

@export var use_custom_models := false:
	set(value):
		use_custom_models = value
		if is_inside_tree():
			_refresh_current_view()

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_refresh_editor_preview()

func build_from_data(data: Dictionary) -> void:
	_last_data = data.duplicate(true)
	_render_data(_last_data)

func _refresh_current_view() -> void:
	if Engine.is_editor_hint():
		_refresh_editor_preview()
	elif not _last_data.is_empty():
		_render_data(_last_data)

func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return

	if not show_editor_preview:
		_clear_existing_meshes()
		return

	var preview_data := _last_data
	if preview_data.is_empty():
		preview_data = _make_editor_preview_data()

	_render_data(preview_data)

func _make_editor_preview_data() -> Dictionary:
	return {
		"id": "BOAT",
		"customization": {
			"primary": "#2f7fff",
			"secondary": "#ffffff",
			"accent": "#ff8800",
		},
		"boat": {
			"pieces": [
				{"id": 2, "x": 0, "y": 0},    # stern
				{"id": 1, "x": 4, "y": 0},    # hull section
				{"id": 1, "x": 8, "y": 0},    # hull section
				{"id": 1, "x": 12, "y": 0},   # hull section
				{"id": 0, "x": 15, "y": 0},   # bow
				{"id": 4, "x": 4, "y": 4},    # big cabin
				{"id": 3, "x": 8, "y": 4},    # cabin
				{"id": 10, "x": 9, "y": 5},   # chimney
				{"id": 11, "x": 12, "y": 4},  # sail
			]
		}
	}
var boat_footprint := Vector3.ZERO

# func _ready() -> void:

## Build directly from a provided data dictionary
func _render_data(data: Dictionary) -> void:
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

		var piece_node := _create_piece_node(
			piece,
			material,
			[primary_color, secondary_color, accent_color]
		)

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

func _clear_existing_meshes() -> void:
	# Removes existing pieces so the constructor can be reused/updated safely
	for child in get_children():
		child.queue_free()

func _create_piece_node(
	piece: Dictionary,
	base_material: StandardMaterial3D,
	piece_colors: Array[Color]
) -> Node3D:
	var id := int(piece.get("id", -1))
	var pos_x := float(piece.get("x", 0)) * SCALE_FACTOR
	var pos_y := float(piece.get("y", 0)) * SCALE_FACTOR
	var flipped := bool(piece.get("flipped", false))

	var piece_node: Node3D
	var is_custom_model := false

	if use_custom_models:
		var packed_scene := _custom_scene_for_piece(id)
		if packed_scene != null:
			piece_node = packed_scene.instantiate() as Node3D
			is_custom_model = piece_node != null # ?






	if is_custom_model:
		piece_node.scale *= SCALE_FACTOR

		var grid_size := _grid_size_for_piece(id)
		piece_node.set_meta("width", grid_size.x * SCALE_FACTOR)
		piece_node.set_meta("height", grid_size.y * SCALE_FACTOR)
		piece_node.set_meta("depth", (6.0 if id <= 2 else 4.0) * SCALE_FACTOR)
	else:
		piece_node = _generate_primitive(id, base_material)

	if piece_node == null:
		return null

	if piece_node is BoatPiece:
		piece_node.set_colors(piece_colors)

	var visual_width := float(piece_node.get_meta("width", 1.0))
	var visual_height := float(piece_node.get_meta("height", 1.0))

	piece_node.position = Vector3(
		pos_x + visual_width / 2.0,
		pos_y + visual_height / 2.0,
		0.0
	)

	if flipped:
		piece_node.scale.x *= -1.0


	print(
		"piece=%d data_x=%.2f root_x=%.2f"
		% [id, pos_x, piece_node.position.x]
	)
	return piece_node


func _grid_size_for_piece(id: int) -> Vector2:
	match id:
		0:
			return Vector2(6, 4) # bow
		1, 2:
			return Vector2(4, 4) # hull section and stern
		3:
			return Vector2(4, 3) # cabin
		_:
			return Vector2.ONE

func _custom_scene_for_piece(id: int) -> PackedScene:
	match id:
		0:
			return HULL_BOW_SCENE
		1:
			return HULL_SECTION_SCENE
		2:
			return HULL_STERN_SCENE
		3:
			return CABIN_SCENE
		10:
			return CHIMNEY_SCENE
		11: 
			return SAIL_SCENE
		_:
			return null

# Sets color of a chosen resource's surface
func _set_surface_color(mesh: MeshInstance3D, surface_idx: int, color: Color) -> void:
	pass

func _generate_primitive(id: int, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var w := 4.0 * SCALE_FACTOR
	var h := 4.0 * SCALE_FACTOR
	var d := 6.0 * SCALE_FACTOR
	var mesh: Mesh

	match id:
		0: # HULL_BOW, 6 × 4 grid units
			w = 6.0 * SCALE_FACTOR
			h = 4.0 * SCALE_FACTOR
			d = 6.0 * SCALE_FACTOR
			var bow_mesh := PrismMesh.new()
			bow_mesh.size = Vector3(w, h, d)
			bow_mesh.left_to_right = 0.0
			mesh = bow_mesh
			mesh_instance.rotation_degrees.x = 180.0

		1: # HULL_SECTION, 4 × 4 grid units
			w = 4.0 * SCALE_FACTOR
			h = 4.0 * SCALE_FACTOR
			d = 6.0 * SCALE_FACTOR
			var section_mesh := BoxMesh.new()
			section_mesh.size = Vector3(w, h, d)
			mesh = section_mesh

		2: # HULL_STERN, 4 × 4 grid units
			w = 4.0 * SCALE_FACTOR
			h = 4.0 * SCALE_FACTOR
			d = 6.0 * SCALE_FACTOR
			var stern_mesh := PrismMesh.new()
			stern_mesh.size = Vector3(w, h, d)
			stern_mesh.left_to_right = 1.0
			mesh = stern_mesh
			mesh_instance.rotation_degrees.x = 180.0

		3: # CABIN, 4 × 3 grid units
			w = 4.0 * SCALE_FACTOR
			h = 4.0 * SCALE_FACTOR
			d = 4.0 * SCALE_FACTOR
			var cabin_mesh := BoxMesh.new()
			cabin_mesh.size = Vector3(w, h, d)
			mesh = cabin_mesh

		4: # BIG_CABIN, 4 × 6 grid units
			w = 4.0 * SCALE_FACTOR
			h = 6.0 * SCALE_FACTOR
			d = 6.0 * SCALE_FACTOR
			var big_cabin_mesh := BoxMesh.new()
			big_cabin_mesh.size = Vector3(w, h, d)
			mesh = big_cabin_mesh

		10: # CHIMNEY, 2 × 4 grid units
			w = 2.0 * SCALE_FACTOR
			h = 4.0 * SCALE_FACTOR
			d = 2.0 * SCALE_FACTOR
			var chimney_mesh := CylinderMesh.new()
			chimney_mesh.top_radius = w * 0.4
			chimney_mesh.bottom_radius = w * 0.45
			chimney_mesh.height = h
			chimney_mesh.radial_segments = 8
			mesh = chimney_mesh

		11: # SAIL placeholder, 8 × 8 grid units
			w = 8.0 * SCALE_FACTOR
			h = 8.0 * SCALE_FACTOR
			d = 1.0 * SCALE_FACTOR
			var bow_mesh := PrismMesh.new()
			bow_mesh.size = Vector3(w, h, d)
			bow_mesh.left_to_right = 0.0
			mesh = bow_mesh

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
