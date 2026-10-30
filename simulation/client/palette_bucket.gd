@tool
class_name PaletteBucket
extends TextureButton

@export var paint_color: Color = Color.WHITE:
	set(value):
		paint_color = value
		if is_node_ready():
			$Paint.modulate = value

@export var border_color: Color = Color.WHITE
@export var border_width := 3
@export var border_radius := 6

var _border: Panel

func _ready() -> void:
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	$Paint.modulate = paint_color
	_create_border()

func _create_border() -> void:
	_border = Panel.new()
	_border.name = "SelectionBorder"
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_border.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(border_radius)
	style.border_color = border_color
	_border.add_theme_stylebox_override("panel", style)

	add_child(_border)  # no owner set, so it isn't saved into the scene

func set_selected(selected: bool) -> void:
	if _border:
		_border.visible = selected
