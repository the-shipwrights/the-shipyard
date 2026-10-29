@tool
extends Control
class_name BoatlessOcean

signal placement_selected(piece_id: int, location: Vector2i)

const OUTLINE_COLOR := Color("#15232a")


## Waterline as a fraction of screen height, measured from the TOP of the screen.
## Everything (waves, gradient, boat) hangs off this one value, so tune it in the Inspector.
@export_range(0.2, 0.9, 0.005) var ocean_level := 0.6
## Horizontal boat position as a fraction of screen width.
@export_range(0.0, 1.0, 0.01) var boat_x := 0.5
## Largest the boat may get, as a fraction of the screen.
@export_range(0.1, 1.0, 0.01) var boat_max_width := 0.5
@export_range(0.1, 1.0, 0.01) var boat_max_height := 0.3
## Draw a simple sky gradient above the water.
@export var draw_sky := true


const SKY_TOP := Color("#87CEEB")
const SKY_BOTTOM := Color("#e4f5f8")
const BACK_WAVE_COLOR := Color("#08404a")
const FRONT_WAVE_COLOR := Color("#008080")
## The colour the water fades to at the bottom of the screen.
const DEEP_TEAL := Color("#08404a")
## The gradient starts this many px above the wave's base line
const GRADIENT_LEAD := 24.0

const WAVE_STEP := 4.0
const WAVE_MARGIN := 40.0
const STEEPNESS := 0.5  # peaked crests; keep the sum of amp*k*steepness below 1

# amplitude (px), wavelength (px), heave speed (rad/s), phase
const SWELLS := [
	[5.0, 280.0, 0.7, 0.0],
	[6.0, 220.0, 0.9, 2.1],
	[4.0, 140.0, 1.0, 3.0],
]

var _time := 0.0




func _ready() -> void:
	clip_contents = true
	# Fill the whole screen. (This is ignored if the parent is a Container -
	# make this node a direct child of your root Control / CanvasLayer, and
	# put it FIRST so the palette and Launch button draw on top of it.)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:

	var waterline := size.y * ocean_level

	if draw_sky:
		_draw_sky(waterline)

	_draw_wave(waterline - 12.0, 0.75, 0.8, 1.0, BACK_WAVE_COLOR)

	_draw_wave(waterline, 1.0, 1.0, 0.0, FRONT_WAVE_COLOR)


func _draw_sky(waterline: float) -> void:
	var bottom := waterline + 40.0  # hidden behind the water
	draw_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(size.x, 0.0),
			Vector2(size.x, bottom),
			Vector2(0.0, bottom),
		]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM])
	)


func _world_to_screen(
	world_point: Vector2,
	world_center: Vector2,
	screen_center: Vector2,
	scale_factor: float
) -> Vector2:
	return screen_center + Vector2(
		(world_point.x - world_center.x) * scale_factor,
		-(world_point.y - world_center.y) * scale_factor
	)

func _wave_offset(
	x0: float,
	amp_scale: float,
	speed_scale: float,
	phase_offset: float
) -> Vector2:
	var offset := Vector2.ZERO

	for w in SWELLS:
		var amp: float = w[0] * amp_scale
		var spatial: float = x0 * TAU / w[1] + w[3] + phase_offset + _time * 0.05
		var heave: float = _time * w[2] * speed_scale + w[3] * 1.7 + phase_offset
		# Fixed shape in x, pulsing in time: up and down, not sliding sideways.
		offset.y -= amp * sin(spatial) * sin(heave)

	return offset


func _draw_wave(
	base_y: float,
	amp_scale: float,
	speed_scale: float,
	phase_offset: float,
	color: Color
) -> void:
	var span := size.x + WAVE_MARGIN * 2.0
	var steps := int(ceil(span / WAVE_STEP))
	var crest := PackedVector2Array()

	for i in range(steps + 1):
		var x0 := -WAVE_MARGIN + span * float(i) / float(steps)
		var o := _wave_offset(x0, amp_scale, speed_scale, phase_offset)
		crest.append(Vector2(x0 + o.x, base_y + o.y))

	var bottom := size.y + 10.0
	var polygon := crest.duplicate()
	polygon.append(Vector2(crest[-1].x, bottom))
	polygon.append(Vector2(crest[0].x, bottom))

	# Vertical gradient: wave colour at the surface -> deep teal at screen bottom.
	# Colour is a linear function of y, so per-vertex colours interpolate exactly.
	var top := base_y - GRADIENT_LEAD
	var span_y := maxf(bottom - top, 1.0)
	var colors := PackedColorArray()
	for p in polygon:
		var t := clampf((p.y - top) / span_y, 0.0, 1.0)
		colors.append(color.lerp(DEEP_TEAL, t))

	draw_polygon(polygon, colors)
	draw_polyline(crest, color.lightened(0.35), 2.0, true)
