extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var level := load("res://levels/prototype_map/prototype_map.tscn").instantiate() as BattleLevel
	level.configure(2, 2, true, 24680, 0, Vector2i(40, 30), false, MissionActor.VIPBehavior.PLAYER_CONTROLLED, null, AIDifficultyPolicy.Tier.NORMAL, true)
	root.add_child(level)
	await create_timer(0.2).timeout
	var rig := level.get_node("CameraRig") as TacticalCamera
	rig.set_process(false)
	var picker := level.battle_controller.mouse_raycaster
	picker.set_process(false)
	var grid := level.battle_controller.grid_manager
	var data := grid.map_data
	var camera := rig.camera
	var original_camera_transform := camera.transform
	# Top-down rays isolate stacked levels without relying on OS pointer state.
	for platform in data.platforms:
		var coordinate: Vector3i = platform.cells[platform.cells.size() / 2]
		var point := data.get_cell(coordinate).world_position
		camera.global_position = point + Vector3.UP * 30.0
		camera.look_at(point, Vector3.FORWARD)
		var screen := camera.unproject_position(point)
		var hit := picker.get_floor_raycast_result(screen)
		check(not hit.is_empty() and hit.grid_position == coordinate, "Platform/tower top is selected by a screen ray: %s" % coordinate)
	for traversal in data.generated_traversals:
		if traversal.kind != GeneratedTraversalData.Kind.STAIRS:
			continue
		for coordinate in traversal.path_cells.slice(1, -1):
			var point := data.get_cell(coordinate).world_position
			camera.global_position = point + Vector3.UP * 30.0
			camera.look_at(point, Vector3.FORWARD)
			var hit := picker.get_floor_raycast_result(camera.unproject_position(point))
			check(not hit.is_empty() and hit.grid_position == coordinate, "Sloped stair input surface selects its step: %s" % coordinate)
	var platform: GeneratedPlatformData = data.platforms[0]
	var ground := Vector3i(platform.footprint.position.x + 1, 0, platform.footprint.position.y + 1)
	var point := data.get_cell(ground).world_position
	camera.global_position = point + Vector3.UP * 30.0
	camera.look_at(point, Vector3.FORWARD)
	var screen := camera.unproject_position(point)
	var candidates := picker.get_floor_candidates(screen)
	check(candidates.size() == 2, "Ray finds the platform and legal ground beneath it")
	picker.get_floor_raycast_result(screen)
	picker.cycle_surface(1, screen)
	var lower := picker.get_floor_raycast_result(screen)
	check(not lower.is_empty() and lower.grid_position == ground, "Cycling selects the hidden ground")
	check(picker.get_floor_raycast_result(screen) == lower, "Repeated preview queries preserve the chosen floor")
	var unit: TacticalUnit = level.turn_manager.active_unit
	unit.global_position = point + Vector3.UP * unit.standing_height
	await physics_frame
	await physics_frame
	check(picker.get_unit_under_mouse(camera.unproject_position(unit.global_position)) == unit, "Bean beneath a platform remains selectable")
	var old_zoom := rig._zoom
	camera.transform = original_camera_transform
	unit.global_position = data.get_cell(data.platforms[-1].cells[4]).world_position + Vector3.UP * unit.standing_height
	rig.focus_selected_unit()
	check(rig.global_position.is_equal_approx(unit.global_position), "Focus centers the selected elevated unit in all three axes")
	check(is_equal_approx(old_zoom, rig._zoom), "Focus preserves zoom")
	for key in [KEY_F, KEY_HOME]:
		rig.global_position = Vector3.ZERO
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		rig._unhandled_input(event)
		check(rig.global_position.is_equal_approx(unit.global_position), "Focus key recovers the selected tower unit")
	var press := InputEventMouseButton.new()
	press.pressed = true
	press.position = Vector2(640, 360)
	press.button_index = MOUSE_BUTTON_LEFT
	rig._unhandled_input(press)
	check(not rig._dragging, "Left click never starts camera dragging")
	press.button_index = MOUSE_BUTTON_RIGHT
	rig._unhandled_input(press)
	check(rig._dragging, "Right press starts camera dragging")
	press.pressed = false
	rig._unhandled_input(press)
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	rig._unhandled_input(press)
	check(rig._rotating, "Middle press preserves camera rotation")
	level.queue_free()
	await process_frame
	print("Elevation selection and camera: %d failure(s)" % failures)
	quit(1 if failures else 0)
