@tool
class_name BoatPiece
extends Node3D

@export var primary_color := Color.WHITE:
	set(value):
		primary_color = value
		_refresh_colors()

@export var meshes: Array[MeshInstance3D]

@export var secondary_color := Color.WHITE:
	set(value):
		secondary_color = value
		_refresh_colors()

@export var detail_color := Color.WHITE:
	set(value):
		detail_color = value
		_refresh_colors()

func _enter_tree() -> void:
	fetch_meshes()
	applyColors()

func _ready() -> void:
	fetch_meshes() # .1 Fetch meshes if we dont already have them
	applyColors()

func _refresh_colors() -> void:
	if not is_inside_tree():
		return

	await fetch_meshes()
	applyColors()

# fetches meshes
func fetch_meshes() -> void:
	if !meshes.is_empty():
		return

	for child in find_children("*", "MeshInstance3D", true, false):
		meshes.append(child as MeshInstance3D)

# Does the hard work of applying colors.
func applyColors() -> void:
	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue

		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_mat := mesh_instance.mesh.surface_get_material(surface_index)
			if not (source_mat is StandardMaterial3D):
				continue

			var color_index := _color_index_for_material(source_mat.resource_name)
			if color_index < 0:
				continue

			var material := source_mat.duplicate() as StandardMaterial3D
			match color_index:
				0:
					material.albedo_color = primary_color
				1:
					material.albedo_color = secondary_color
				2:
					material.albedo_color = detail_color

			mesh_instance.set_surface_override_material(surface_index, material)


# sets colors of each color. Useful for when a boat piece is created.
func set_colors(colors: Array[Color]) -> void:
	primary_color = colors[0]
	secondary_color = colors[1]
	detail_color = colors[2]

func _color_index_for_material(material_name: String) -> int:
	var normalized_name := material_name.to_lower()
	if normalized_name.begins_with("primary"):
		return 0
	if normalized_name.begins_with("secondary"):
		return 1
	if normalized_name.begins_with("detail"):
		return 2
	return -1
