@tool
extends GridContainer

signal color_selected(color: Color)

enum SwatchShape {
	SQUARE,
	ROUNDED,
	CIRCLE,
}

var _selected_index := -1
var _swatches: Array[Control] = []
var _cell_size := Vector2.ZERO

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

@export_enum("Square", "Rounded", "Circle")
var swatch_shape: int = SwatchShape.ROUNDED:
	set(value):
		swatch_shape = value
		_refresh_swatches()

@export_range(0.0, 0.5, 0.01)
var corner_radius_ratio := 0.18:
	set(value):
		corner_radius_ratio = value
		_refresh_swatches()

@export_range(0, 32, 1)
var grid_gap := 8:
	set(value):
		grid_gap = maxi(value, 0)
		if is_inside_tree():
			_apply_grid_gap()
			_resize_swatches()

@export_range(8, 128, 1)
var min_swatch_size := 24

@export_range(8, 128, 1)
var max_swatch_size := 72:
	set(value):
		max_swatch_size = value
		_resize_swatches()

@export_range(0, 12, 1)
var selection_border_width := 3:
	set(value):
		selection_border_width = value
		_refresh_swatches()

@export var use_contrast_selection_border := true:
	set(value):
		use_contrast_selection_border = value
		_refresh_swatches()

@export var selection_border_color := Color.WHITE:
	set(value):
		selection_border_color = value
		_refresh_swatches()


func _ready() -> void:
	_apply_grid_gap()
	resized.connect(_queue_resize_swatches)
	visibility_changed.connect(_queue_resize_swatches)
	_rebuild_palette()
	call_deferred("_resize_swatches")


func _apply_grid_gap() -> void:
	add_theme_constant_override("h_separation", grid_gap)
	add_theme_constant_override("v_separation", grid_gap)


func _queue_resize_swatches() -> void:
	call_deferred("_resize_swatches")


func _resize_swatches() -> void:
	if not is_inside_tree() or _swatches.is_empty():
		return

	if size.x <= 0.0 or size.y <= 0.0:
		return

	var column_count := maxi(columns, 1)
	var row_count := ceili(float(_swatches.size()) / float(column_count))

	var available_cell_width := (
		size.x - float(grid_gap * (column_count - 1))
	) / float(column_count)

	var available_cell_height := (
		size.y - float(grid_gap * (row_count - 1))
	) / float(row_count)

	# Let cells fall below the preferred minimum when necessary to fit
	# a small screen. The maximum prevents oversized swatches on tablets.
	var fitted_size := maxf(
		1.0,
		minf(available_cell_width, available_cell_height)
	)
	var new_cell_size := minf(fitted_size, float(max_swatch_size))

	if is_equal_approx(new_cell_size, _cell_size.x):
		return

	_cell_size = Vector2(new_cell_size, new_cell_size)

	for swatch in _swatches:
		swatch.custom_minimum_size = _cell_size

	_refresh_swatches()


func _rebuild_palette() -> void:
	if not is_inside_tree():
		return

	_remove_generated_swatches()
	_swatches.clear()
	_selected_index = -1

	for index in range(palette_colors.size()):
		var swatch := Control.new()
		swatch.name = "PaletteSwatch"
		swatch.custom_minimum_size = _cell_size
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.set_meta("_palette_generated", true)

		add_child(swatch)
		_assign_editor_owner(swatch)

		var color_panel := Panel.new()
		color_panel.name = "Color"
		color_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		color_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		color_panel.gui_input.connect(
			_on_swatch_gui_input.bind(index)
		)

		swatch.add_child(color_panel)
		_assign_editor_owner(color_panel)

		_swatches.append(swatch)

	_apply_grid_gap()
	_resize_swatches()
	_refresh_swatches()


func _on_swatch_gui_input(event: InputEvent, index: int) -> void:
	var activated := false

	if event is InputEventMouseButton:
		activated = (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		)
	elif event is InputEventScreenTouch:
		activated = event.pressed

	if not activated or index >= palette_colors.size():
		return
	_on_bucket_pressed(index)

func _on_bucket_pressed(index: int) -> void:
	_selected_index = index
	_refresh_swatches()
	color_selected.emit(palette_colors[index])


func _refresh_swatches() -> void:
	if _swatches.is_empty():
		return

	for index in range(_swatches.size()):
		if index >= palette_colors.size():
			continue

		var color_panel := _swatches[index].get_node_or_null("Color") as Panel
		if color_panel == null:
			continue

		color_panel.add_theme_stylebox_override(
			"panel",
			_make_swatch_style(
				palette_colors[index],
				index == _selected_index
			)
		)


func _make_swatch_style(color: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color

	var radius := 0
	var shortest_side := minf(_cell_size.x, _cell_size.y)

	match swatch_shape:
		SwatchShape.ROUNDED:
			radius = roundi(shortest_side * corner_radius_ratio)
		SwatchShape.CIRCLE:
			radius = roundi(shortest_side * 0.5)

	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius

	if selected and selection_border_width > 0:
		var border_color := selection_border_color

		if use_contrast_selection_border:
			border_color = (
				Color(0.1, 0.1, 0.1, 1.0)
				if color.get_luminance() > 0.65
				else Color.WHITE
			)

		style.border_width_left = selection_border_width
		style.border_width_top = selection_border_width
		style.border_width_right = selection_border_width
		style.border_width_bottom = selection_border_width
		style.border_color = border_color

	return style


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

func clear_selection() -> void:
	_selected_index = -1
	
func select_color(color: Color) -> void:
	_selected_index = palette_colors.find(color)  # -1 if there's no match, which clears it
