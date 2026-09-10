extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var floor = CSGBox3D.new()
	floor.size = Vector3(6.0, 0.2, 6.0)
	root.add_child(floor)

	var grid = GridManager.new()
	grid.map_floor = floor
	root.add_child(grid)
	var pathfinder = Pathfinder.new()

	var cells = [
		Vector3i(1, 0, 1),
		Vector3i(2, 1, 1),
		Vector3i(3, 1, 1),
		Vector3i(4, 3, 1),
		Vector3i(2, 0, 1),
	]
	for cell in cells:
		var world_position = grid.grid_to_world(cell)
		grid.map_data.add_cell(MapCellData.new(cell, world_position))
		pathfinder.add_walkable_cell(cell, world_position)

	check(grid.map_data.cells.size() == 5, "Cells at the same x/z can exist at different elevations")
	check(grid.map_data.get_column_cells(2, 1).size() == 2, "A map column exposes all of its elevation layers")
	check(is_equal_approx(grid.grid_to_world(Vector3i(2, 1, 1)).y - grid.grid_to_world(Vector3i(2, 0, 1)).y, 1.0), "Elevation levels convert to world height")
	check(grid.world_to_grid(grid.grid_to_world(Vector3i(2, 1, 1))) == Vector3i(2, 1, 1), "A surface point resolves to its elevation layer")
	check(pathfinder.calculate_3d_path(Vector3i(1, 0, 1), Vector3i(3, 1, 1)).size() == 3, "A one-level neighboring step is traversable")
	check(pathfinder.calculate_3d_path(Vector3i(3, 1, 1), Vector3i(4, 3, 1)).is_empty(), "A large height gap needs a future traversal link")
	check(pathfinder.get_reachable_cells(Vector3i(1, 0, 1), 2).has(Vector3i(3, 1, 1)), "Movement range follows elevation-aware graph connections")

	var lower_unit = TacticalUnit.new()
	var upper_unit = TacticalUnit.new()
	grid.register_unit(lower_unit, Vector3i(2, 0, 1))
	grid.register_unit(upper_unit, Vector3i(2, 1, 1))
	check(grid.get_unit_grid(lower_unit) == Vector3i(2, 0, 1), "A unit remembers its authoritative grid layer")
	check(grid.get_unit_at(Vector3i(2, 0, 1)) == lower_unit and grid.get_unit_at(Vector3i(2, 1, 1)) == upper_unit, "Occupancy distinguishes stacked elevation cells")

	grid.occupancy_map.clear()
	lower_unit.free()
	upper_unit.free()
	grid.queue_free()
	floor.queue_free()
	await process_frame
	print("Elevation smoke: %d failure(s)" % failures)
	quit(1 if failures else 0)
