@tool
extends GridContainer

signal color_selected(color: Color)

const BUCKET_SCENE := preload("res://UI/palette_bucket.tscn")  # your path

var _selected_index := -1
var _swatches: Array[PaletteBucket] = []

@export var palette_colors: Array[Color] = [
	Color("#e74243"),
	Color("#eb8e5a"),
	Color("#e9cc61"),
	Color("#d1e376"),
	Color("#a7bb73"),
	Color("#7fd260"),
	Color("#42cb6d"),
	Color("#4bb79a"),
	Color("#46b1c4"),
	Color("#4f92f4"),
	Color("#6e75c9"),
	Color("#b2556f"),
	Color("#c7a789"),
	Color("#b19f98"),
	Color("#d5d3d4"),
]:
	set(value):
		palette_colors = value
		if is_inside_tree():
			_rebuild_palette()

func _ready() -> void:
	_rebuild_palette()

func _rebuild_palette() -> void:
	if not is_inside_tree():
		return

	_remove_generated_swatches()
	_swatches.clear()

	for index in range(palette_colors.size()):
		var bucket: PaletteBucket = BUCKET_SCENE.instantiate()
		bucket.paint_color = palette_colors[index]
		bucket.set_meta("_palette_generated", true)
		bucket.pressed.connect(_on_bucket_pressed.bind(index))

		add_child(bucket)
		_assign_editor_owner(bucket)

		bucket.set_selected(index == _selected_index)
		_swatches.append(bucket)

func _on_bucket_pressed(index: int) -> void:
	_selected_index = index
	_update_selection_visuals()
	color_selected.emit(palette_colors[index])

func _update_selection_visuals() -> void:
	for index in range(_swatches.size()):
		_swatches[index].set_selected(index == _selected_index)

# _remove_generated_swatches() and _assign_editor_owner() stay exactly as they are

func _remove_generated_swatches() -> void:
	for child in get_children():
		if child.get_meta("_palette_generated", false):
			child.free()


func _assign_editor_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return

	var edited_scene_root := get_tree().edited_scene_root

	if edited_scene_root != null:
		node.owner = edited_scene_root
