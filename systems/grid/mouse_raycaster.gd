extends Node3D
class_name MouseRaycaster

# 1. THE MISSING LINK: Define the signal the BattleController is trying to connect to
signal floor_clicked(raw_position: Vector3)

@export var camera: Camera3D

# 2. THE CLICK LISTENER: Listens for a physical left mouse click
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit_pos = get_raycast_result()
		# If the raycast successfully hit the floor grid, broadcast the event!
		if hit_pos != Vector3.ZERO:
			floor_clicked.emit(hit_pos)

# 3. THE HOVER ENGINE: Continuously used by the BattleController for the cursor highlight
func get_raycast_result() -> Vector3:
	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera:
			return Vector3.ZERO

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_length = 1000.0
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * ray_length
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	query.collision_mask = 2 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
		
	return Vector3.ZERO
