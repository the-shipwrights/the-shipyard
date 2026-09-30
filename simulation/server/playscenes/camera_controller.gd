extends Camera3D

@export var move_speed: float = 12.0
@export var sprint_multiplier: float = 2.5
@export var mouse_sensitivity: float = 0.003

var _is_dragging: bool = false

func _unhandled_input(event: InputEvent) -> void:
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
