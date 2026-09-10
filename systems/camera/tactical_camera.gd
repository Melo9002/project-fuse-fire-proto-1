class_name TacticalCamera
extends Node3D

@export var map_floor: CSGBox3D
@export var camera: Camera3D
@export var pan_speed: float = 12.0
@export var edge_margin: float = 18.0
@export var map_margin: float = 2.0
@export var rotation_speed: float = 90.0
@export var drag_sensitivity: float = 0.3
@export var min_zoom: float = 20.0
@export var max_zoom: float = 56.0
@export var zoom_step: float = 3.0

var _zoom: float = 42.0
var _rotating: bool = false

func _ready() -> void:
	if not map_floor or not camera:
		push_error("TacticalCamera: missing map floor or camera reference")
		set_process(false)
		return
	_zoom = clampf(camera.position.z, min_zoom, max_zoom)
	camera.position.z = _zoom

func _process(delta: float) -> void:
	var input_direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_direction.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_direction.y -= 1.0

	if not _rotating:
		var mouse = get_viewport().get_mouse_position()
		var viewport_size = get_viewport().get_visible_rect().size
		if mouse.x <= edge_margin:
			input_direction.x -= 1.0
		elif mouse.x >= viewport_size.x - edge_margin:
			input_direction.x += 1.0
		if mouse.y <= edge_margin:
			input_direction.y += 1.0
		elif mouse.y >= viewport_size.y - edge_margin:
			input_direction.y -= 1.0

	if input_direction != Vector2.ZERO:
		_pan(input_direction.normalized(), delta)

	var turn_direction := 0.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_PAGEUP):
		turn_direction -= 1.0
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_PAGEDOWN):
		turn_direction += 1.0
	if turn_direction != 0.0:
		rotate_y(deg_to_rad(-turn_direction * rotation_speed * delta))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_rotating = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom - zoom_step)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom + zoom_step)
	elif event is InputEventMouseMotion and _rotating:
		rotate_y(deg_to_rad(-event.relative.x * drag_sensitivity))

func _pan(direction: Vector2, delta: float) -> void:
	var right = Vector3.RIGHT.rotated(Vector3.UP, rotation.y)
	var forward = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	global_position += (right * direction.x + forward * direction.y) * pan_speed * delta
	_clamp_to_map()

func _set_zoom(value: float) -> void:
	_zoom = clampf(value, min_zoom, max_zoom)
	camera.position.z = _zoom

func _clamp_to_map() -> void:
	var center = map_floor.global_position
	var half_width = map_floor.size.x * 0.5 + map_margin
	var half_depth = map_floor.size.z * 0.5 + map_margin
	global_position.x = clampf(global_position.x, center.x - half_width, center.x + half_width)
	global_position.z = clampf(global_position.z, center.z - half_depth, center.z + half_depth)
