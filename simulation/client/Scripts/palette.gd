@tool
extends GridContainer

signal color_selected(color: Color)

var _selected_index := -1
var _swatches: Array[Control] = []

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
		var color := palette_colors[index]

		var swatch_container := Control.new()
		swatch_container.name = "PaletteSwatch"
		swatch_container.custom_minimum_size = Vector2(70.0, 70.0)
		swatch_container.size = Vector2(70.0, 70.0)
		swatch_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch_container.set_meta("_palette_generated", true)

		add_child(swatch_container)
		_assign_editor_owner(swatch_container)

		var color_rect := ColorRect.new()
		color_rect.name = "Color"
		color_rect.size = Vector2(70.0, 70.0)
		color_rect.color = color
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

		color_rect.gui_input.connect(
			_on_color_rect_gui_input.bind(index)
		)

		swatch_container.add_child(color_rect)
		_assign_editor_owner(color_rect)

		var selection_border := Panel.new()
		selection_border.name = "SelectionBorder"
		selection_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selection_border.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

		selection_border.add_theme_stylebox_override(
			"panel",
			_make_selection_style(index == _selected_index, color)
		)

		swatch_container.add_child(selection_border)
		_assign_editor_owner(selection_border)

		_swatches.append(swatch_container)

func _on_color_rect_gui_input(
	event: InputEvent,
	index: int
) -> void:
	var activated := false

	if event is InputEventMouseButton:
		activated = (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		)
	elif event is InputEventScreenTouch:
		activated = event.pressed

	if not activated:
		return

	_selected_index = index
	_update_selection_visuals()

	color_selected.emit(palette_colors[index])

func _make_selection_style(
	selected: bool,
	swatch_color: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)

	if selected:
		var border_color := Color.WHITE

		# Use a dark border for very light swatches.
		if swatch_color.get_luminance() > 0.65:
			border_color = Color(0.1, 0.1, 0.1, 1.0)

		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = border_color

	return style

func _update_selection_visuals() -> void:
	for index in range(_swatches.size()):
		var border := _swatches[index].get_node_or_null(
			"SelectionBorder"
		) as Panel

		if border == null:
			continue

		border.add_theme_stylebox_override(
			"panel",
			_make_selection_style(
				index == _selected_index,
				palette_colors[index]
			)
		)

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
