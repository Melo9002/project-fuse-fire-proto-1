extends Node3D
class_name MouseRaycaster
signal floor_clicked(raw_position: Vector3)
signal unit_clicked(unit: TacticalUnit)

@export var camera: Camera3D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_unit = get_unit_under_mouse()
		if clicked_unit:
			unit_clicked.emit(clicked_unit)
			return

		var floor_hit = get_floor_raycast_result()
		if not floor_hit.is_empty():
			floor_clicked.emit(floor_hit.position)

func get_floor_raycast_result() -> Dictionary:
	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera:
			return {}

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_length = 1000.0
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * ray_length

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)

	query.collision_mask = 2

	var result = space_state.intersect_ray(query)

	if result:
		return result

	return {}

func get_unit_under_mouse() -> TacticalUnit:
	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera:
			return null

	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 4

	var result = get_world_3d().direct_space_state.intersect_ray(query)
	return result.collider as TacticalUnit if result else null
