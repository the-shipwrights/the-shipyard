extends Control

signal boat_launched(boat_data: Dictionary)

@export var server_api_base := "http://127.0.0.1:8000"
@export var web_api_base := ""

const COLOR_FIELDS := ["primary", "secondary", "accent"]

var boat_data: Dictionary = {}
var selected_colors: Dictionary = {}
var active_color_field := "primary"
var launch_request := HTTPRequest.new()
var default_launch_text := ""

@onready var boat_preview: BoatPreview2D = %BoatPreview2D
@onready var launch_button: Button = $SafeArea/Content/LaunchButton
@onready var status_label: Label = $SafeArea/Content/StatusLabel
@onready var boat_label: Label = $SafeArea/Content/Label
@onready var palette: GridContainer = $SafeArea/Content/PaletteRegion/Palette

@onready var primary_button: TextureButton = $SafeArea/Content/ColorSelector/Primary/TextureButton
@onready var secondary_button: TextureButton = $SafeArea/Content/ColorSelector/Secondary/TextureButton
@onready var accent_button: TextureButton = $SafeArea/Content/ColorSelector/Accent/TextureButton

@onready var primary_swatch: Panel = $SafeArea/Content/ColorSelector/Primary/Color
@onready var secondary_swatch: Panel = $SafeArea/Content/ColorSelector/Secondary/Color
@onready var accent_swatch: Panel = $SafeArea/Content/ColorSelector/Accent/Color


func _ready() -> void:
	default_launch_text = launch_button.text
	add_child(launch_request)
	launch_request.request_completed.connect(_on_launch_completed)

	palette.color_selected.connect(_on_palette_color_selected)

	var circle_mask := _make_circle_mask(64)
	primary_button.texture_click_mask = circle_mask
	secondary_button.texture_click_mask = circle_mask
	accent_button.texture_click_mask = circle_mask

	primary_button.pressed.connect(_on_color_field_selected.bind("primary"))
	secondary_button.pressed.connect(_on_color_field_selected.bind("secondary"))
	accent_button.pressed.connect(_on_color_field_selected.bind("accent"))

	for button in [primary_button, secondary_button, accent_button]:
		button.disabled = true

	launch_button.pressed.connect(launch_boat)

func _make_circle_mask(size: int) -> BitMap:
	var mask := BitMap.new()
	mask.create(Vector2i(size, size))

	var center := Vector2(size / 2.0, size / 2.0)
	var radius := size / 2.0

	for y in size:
		for x in size:
			var point := Vector2(x + 0.5, y + 0.5)
			if point.distance_to(center) <= radius:
				mask.set_bit(x, y, true)

	return mask

func setup(data: Dictionary) -> void:
	boat_data = data
	boat_preview.set_boat(data)

	boat_label.text = "Boat #" + str(boat_data.get("id", ""))

	var customization: Dictionary = boat_data.get("customization", {})

	selected_colors.clear()
	for field in COLOR_FIELDS:
		selected_colors[field] = _random_palette_color()

	for button in [primary_button, secondary_button, accent_button]:
		button.disabled = false

	_update_color_buttons()
	boat_preview.set_customization(selected_colors)

	launch_button.text = default_launch_text
	launch_button.disabled = false
	launch_button.show()
	status_label.text = ""
	palette.select_color(selected_colors[active_color_field])

func _get_api_base() -> String:
	if OS.has_feature("web"):
		if not web_api_base.is_empty():
			return web_api_base.trim_suffix("/")

		var window = JavaScriptBridge.get_interface("window")
		var scheme := "https" if str(window.location.protocol) == "https:" else "http"
		return "%s://%s" % [scheme, str(window.location.host)]

	return server_api_base.trim_suffix("/")

func _random_palette_color() -> Color:
	if palette.palette_colors.is_empty():
		return Color("#2f7fff")

	return palette.palette_colors[
		randi_range(0, palette.palette_colors.size() - 1)
	]


func _on_color_field_selected(field: String) -> void:
	if not selected_colors.has(field):
		push_warning("Color selector pressed before setup initialized: " + field)
		return

	active_color_field = field
	palette.select_color(selected_colors[field])
	_update_color_buttons()


func _on_palette_color_selected(color: Color) -> void:
	selected_colors[active_color_field] = color
	_update_color_buttons()
	boat_preview.set_customization(selected_colors)


func _update_color_buttons() -> void:
	_update_color_swatch("primary", primary_swatch)
	_update_color_swatch("secondary", secondary_swatch)
	_update_color_swatch("accent", accent_swatch)


func _update_color_swatch(field: String, swatch: Panel) -> void:
	if not selected_colors.has(field):
		return

	var color: Color = selected_colors[field]
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 32
	style.corner_radius_top_right = 32
	style.corner_radius_bottom_left = 32
	style.corner_radius_bottom_right = 32

	var is_active := field == active_color_field
	var border_width := 3 if is_active else 1
	var border_color := Color.WHITE if color.get_luminance() <= 0.65 else Color.BLACK

	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color if is_active else color.darkened(0.25)

	swatch.add_theme_stylebox_override("panel", style)


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


func _launched_boat_data() -> Dictionary:
	var launched_data: Dictionary = boat_data.duplicate(true)
	launched_data["status"] = "launched"
	launched_data["customization"] = {
		"primary": _color_to_hex(selected_colors["primary"]),
		"secondary": _color_to_hex(selected_colors["secondary"]),
		"accent": _color_to_hex(selected_colors["accent"]),
	}
	return launched_data


func launch_boat() -> void:
	launch_button.text = "Sending boat..."
	launch_button.disabled = true
	status_label.text = ""

	var body := JSON.stringify({
		"primary": _color_to_hex(selected_colors["primary"]),
		"secondary": _color_to_hex(selected_colors["secondary"]),
		"accent": _color_to_hex(selected_colors["accent"]),
	})
	var headers := PackedStringArray(["Content-Type: application/json"])

	var error := launch_request.request(
		_get_api_base() + "/api/boats/" + str(boat_data.get("id")) + "/launch",
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		_reset_launch_button()
		status_label.text = "Could not send launch request"


func _on_launch_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		status_label.text = "Boat launched!"
		launch_button.hide()
		var launched_data := _launched_boat_data()
		var response_data = JSON.parse_string(body.get_string_from_utf8())
		if response_data is Dictionary:
			var response_boat: Dictionary = response_data
			if response_boat.has("boat"):
				var selected_customization: Dictionary = launched_data["customization"]
				launched_data.merge(response_boat, true)
				launched_data["status"] = "launched"
				launched_data["customization"] = selected_customization
			else:
				push_warning("[Launch] Server response did not include boat data; using the submitted boat data.")
		else:
			push_warning("[Launch] Server returned success without a boat JSON object; using the submitted boat data.")
		boat_launched.emit(launched_data)
	elif response_code == 409:
		status_label.text = "Boat already launched!"
		launch_button.hide()
		boat_launched.emit(_launched_boat_data())
	else:
		_reset_launch_button()
		status_label.text = "Launch failed (" + str(response_code) + ")"
		push_error("Launch failed with code: " + str(response_code))


func _reset_launch_button() -> void:
	launch_button.text = default_launch_text
	launch_button.disabled = false
	
	
