extends Control

signal boat_launched(boat_data: Dictionary)

const API_BASE := "http://localhost:8000"
const COLOR_FIELDS := ["primary", "secondary", "accent"]

var boat_data: Dictionary = {}
var selected_colors: Dictionary = {}
var active_color_field := "primary"
var launch_request := HTTPRequest.new()

@onready var launch_button: Button = $LaunchButton
@onready var status_label: Label = $StatusLabel
@onready var boat_label: Label = $Label
@onready var palette: GridContainer = $Palette
@onready var primary_button: Button = $ColorSelector/Primary
@onready var secondary_button: Button = $ColorSelector/Secondary
@onready var accent_button: Button = $ColorSelector/Accent


func _ready() -> void:
	add_child(launch_request)
	launch_request.request_completed.connect(_on_launch_completed)

	palette.color_selected.connect(_on_palette_color_selected)

	primary_button.pressed.connect(_on_color_field_selected.bind("primary"))
	secondary_button.pressed.connect(_on_color_field_selected.bind("secondary"))
	accent_button.pressed.connect(_on_color_field_selected.bind("accent"))

	launch_button.pressed.connect(launch_boat)


func setup(data: Dictionary) -> void:
	boat_data = data
	boat_label.text = "Boat #" + str(boat_data.get("id", ""))

	var customization: Dictionary = boat_data.get("customization", {})

	for field in COLOR_FIELDS:
		selected_colors[field] = _random_palette_color()

	_update_color_buttons()

	launch_button.disabled = false
	launch_button.show()
	status_label.text = ""


func _random_palette_color() -> Color:
	if palette.palette_colors.is_empty():
		return Color("#2f7fff")

	return palette.palette_colors[
		randi_range(0, palette.palette_colors.size() - 1)
	]


func _on_color_field_selected(field: String) -> void:
	active_color_field = field
	_update_color_buttons()


func _on_palette_color_selected(color: Color) -> void:
	selected_colors[active_color_field] = color
	_update_color_buttons()


func _update_color_buttons() -> void:
	_update_color_button("primary", primary_button)
	_update_color_button("secondary", secondary_button)
	_update_color_button("accent", accent_button)


func _update_color_button(field: String, button: Button) -> void:
	if not selected_colors.has(field):
		return

	var color: Color = selected_colors[field]
	var text_color := Color.BLACK if color.get_luminance() > 0.55 else Color.WHITE
	var border_color := Color.WHITE if color.get_luminance() <= 0.65 else Color.BLACK

	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)

	button.add_theme_stylebox_override(
		"normal",
		_make_button_style(color, field == active_color_field, border_color)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_button_style(color.lightened(0.08), field == active_color_field, border_color)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_button_style(color.darkened(0.08), field == active_color_field, border_color)
	)
	button.add_theme_stylebox_override(
		"focus",
		_make_button_style(color, true, border_color)
	)


func _make_button_style(
	color: Color,
	is_active: bool,
	border_color: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4

	var border_width := 3 if is_active else 1
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color if is_active else color.darkened(0.25)

	return style


func _color_to_hex(color: Color) -> String:
	return "#" + color.to_html(false)


func launch_boat() -> void:
	status_label.text = "Sending boat..."
	launch_button.disabled = true

	var body := JSON.stringify({
		"primary": _color_to_hex(selected_colors["primary"]),
		"secondary": _color_to_hex(selected_colors["secondary"]),
		"accent": _color_to_hex(selected_colors["accent"]),
	})
	var headers := PackedStringArray(["Content-Type: application/json"])

	var error := launch_request.request(
		API_BASE + "/api/boats/" + str(boat_data.get("id")) + "/launch",
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		status_label.text = "Could not send launch request"
		launch_button.disabled = false


func _on_launch_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	launch_button.disabled = false

	if response_code == 200:
		status_label.text = "Boat launched!"
		launch_button.hide()
		var updated_data = JSON.parse_string(body.get_string_from_utf8())
		if updated_data is Dictionary:
			boat_launched.emit(updated_data)
	elif response_code == 409:
		status_label.text = "Boat already launched!"
		boat_data["status"] = "launched"
		boat_launched.emit(boat_data)
	else:
		status_label.text = "Launch failed (" + str(response_code) + ")"
		push_error("Launch failed with code: " + str(response_code))