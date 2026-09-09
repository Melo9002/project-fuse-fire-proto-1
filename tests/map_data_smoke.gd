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
	var low_cover_cell = grid.world_to_grid(Vector3(-5.0, 0.0, 2.5))
	var open_cell = grid.world_to_grid(Vector3(0.5, 0.0, 0.5))
	var wall_data = grid.get_cell_data(wall_cell)
	var low_cover_data = grid.get_cell_data(low_cover_cell)
	var open_data = grid.get_cell_data(open_cell)

	check(grid.map_data.cells.size() == 400, "Map data contains every 20 x 20 cell")
	check(wall_data != null and wall_data.walkable and not wall_data.can_stop, "Low cover can be crossed but not occupied")
	check(wall_data != null and wall_data.cover_type == MapCellData.CoverType.LOW, "Small block exposes low cover")
	check(wall_data != null and not wall_data.blocks_line_of_sight, "Small block permits shots")
	check(wall_data != null and wall_data.movement_cost == 2, "Vaulting costs two movement points")
	check(low_cover_data != null and low_cover_data.cover_type == MapCellData.CoverType.LOW, "One-meter obstacle exposes low cover")
	check(low_cover_data != null and is_equal_approx(low_cover_data.cover_height, 1.0), "Cover height remains separate from cover type")
	check(low_cover_data != null and not low_cover_data.blocks_line_of_sight, "Low cover does not block line of sight")
	check(open_data != null and open_data.walkable and open_data.cover_type == MapCellData.CoverType.NONE, "Open terrain has no cover")
	check(grid.occupancy_map.has(open_cell), "Unit occupancy remains separate from terrain data")
	check(open_data.walkable, "An occupied cell remains walkable terrain")

	level.queue_free()
	await process_frame
	print("Map data smoke: %d failure(s)" % failures)
	quit(1 if failures else 0)
