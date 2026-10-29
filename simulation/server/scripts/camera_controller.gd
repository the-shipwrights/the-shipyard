@tool
extends Camera3D

@export var move_speed: float = 12.0
@export var sprint_multiplier: float = 2.5
@export var mouse_sensitivity: float = 0.003

var _is_dragging: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey \
			and event.keycode == KEY_F12 \
			and event.pressed \
			and not event.echo:
		take_screenshot()
	# Click & drag to look around
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _is_dragging else Input.MOUSE_MODE_VISIBLE

	elif event is InputEventMouseMotion and _is_dragging:
		# Yaw around global Y axis
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Pitch around local camera X axis
		rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
		# Prevent camera from flipping over vertically
		rotation.x = clamp(rotation.x, -deg_to_rad(85), deg_to_rad(85))

func _process(delta: float) -> void:
	var move_vec := Vector3.ZERO

	# WASD Navigation relative to camera view
	if Input.is_key_pressed(KEY_W):
		move_vec -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		move_vec += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		move_vec -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		move_vec += transform.basis.x

	# Elevation controls
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		move_vec += Vector3.UP
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		move_vec -= Vector3.UP

	if move_vec != Vector3.ZERO:
		var speed := move_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= sprint_multiplier
		global_position += move_vec.normalized() * speed * delta


@export var screenshot_size := Vector2i(2160, 3840)
@export_file("*.png") var screenshot_path := "res://landscape.png"
@export_tool_button("Screenshot") var button := take_screenshot


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey \
			and event.keycode == KEY_F12 \
			and event.pressed \
			and not event.echo:
		take_screenshot()


func take_screenshot() -> void:
	if Engine.is_editor_hint():
		push_warning("Run the scene and press F12 to capture the game camera.")
		return

	var source_viewport := get_viewport()
	var capture_viewport := SubViewport.new()
	capture_viewport.size = screenshot_size
	capture_viewport.world_3d = source_viewport.world_3d
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	get_tree().current_scene.add_child(capture_viewport)

	var capture_camera := duplicate() as Camera3D
	capture_camera.set_script(null)
	capture_viewport.add_child(capture_camera)
	capture_camera.global_transform = global_transform
	capture_camera.make_current()

	# Let the SubViewport render its first frame before reading its texture.
	await RenderingServer.frame_post_draw

	var image := capture_viewport.get_texture().get_image()
	print("Capture size: ", image.get_size())

	var error := image.save_png(screenshot_path)
	capture_viewport.queue_free()

	if error != OK:
		push_error("Could not save screenshot: %s" % error)
	else:
		print("Screenshot saved to: ", screenshot_path)
