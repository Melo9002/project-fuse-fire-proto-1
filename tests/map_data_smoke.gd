extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var level = load("res://levels/prototype_map/prototype_map.tscn").instantiate()
	root.add_child(level)
	await create_timer(0.15).timeout

	var grid: GridManager = level.get_node("Systems/GridManager")
	var wall_cell = grid.world_to_grid(Vector3(2.5, 0.0, 2.5))
	var open_cell = grid.world_to_grid(Vector3(0.5, 0.0, 0.5))
	var wall_data = grid.get_cell_data(wall_cell)
	var open_data = grid.get_cell_data(open_cell)

	check(grid.map_data.cells.size() == 400, "Map data contains every 20 x 20 cell")
	check(wall_data != null and not wall_data.walkable, "Obstacle cell is not walkable")
	check(wall_data != null and wall_data.cover_type == MapCellData.CoverType.LOW, "Authored obstacle exposes low cover")
	check(wall_data != null and is_equal_approx(wall_data.cover_height, 1.0), "Cover height remains separate from cover type")
	check(wall_data != null and not wall_data.blocks_line_of_sight, "Low cover data does not claim to block line of sight")
	check(open_data != null and open_data.walkable and open_data.cover_type == MapCellData.CoverType.NONE, "Open terrain has no cover")
	check(grid.occupancy_map.has(open_cell), "Unit occupancy remains separate from terrain data")
	check(open_data.walkable, "An occupied cell remains walkable terrain")

	level.queue_free()
	await process_frame
	print("Map data smoke: %d failure(s)" % failures)
	quit(1 if failures else 0)

