@tool
extends Camera3D

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
