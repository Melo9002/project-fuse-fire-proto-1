extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var level = load("res://levels/prototype_map/prototype_map.tscn").instantiate() as BattleLevel
	level.configure(5, 5)
	root.add_child(level)
	await create_timer(0.15).timeout

	var battle = level.battle_controller
	var grid = battle.grid_manager
	check(grid.map_floor.size == Vector3(24, 1, 20), "Battlefield is 24 by 20 tiles")
	check(grid.map_data.cells.size() == 492, "Map data contains 480 ground and 12 platform cells")
	for obstacle in level.get_node("Environment/Obstacles").get_children():
		var minimum = obstacle.position - obstacle.size * 0.5
		var maximum = obstacle.position + obstacle.size * 0.5
		check(is_equal_approx(minimum.x, roundf(minimum.x)) and is_equal_approx(maximum.x, roundf(maximum.x)), "%s aligns with x grid lines" % obstacle.name)
		check(is_equal_approx(minimum.z, roundf(minimum.z)) and is_equal_approx(maximum.z, roundf(maximum.z)), "%s aligns with z grid lines" % obstacle.name)

	var low_count := 0
	var full_count := 0
	for cell in grid.map_data.cells.values():
		if cell.cover_type == MapCellData.CoverType.LOW:
			low_count += 1
			check(cell.walkable and not cell.can_stop and cell.movement_cost == 2, "Low cover is configured for vaulting")
		elif cell.cover_type == MapCellData.CoverType.FULL:
			full_count += 1
			check(not cell.walkable and not cell.can_stop and cell.blocks_line_of_sight, "Full cover blocks traversal and LOS")
	check(low_count > 10, "Battlefield contains several low-cover approaches")
	print("Battlefield cover cells: low=", low_count, " full=", full_count)
	check(full_count > 10, "Battlefield contains substantial full-cover walls")

	var ladder_bottom := Vector3i(5, 0, 4)
	var ladder_top := Vector3i(5, 2, 3)
	var platform_center := Vector3i(6, 2, 2)
	check(grid.get_cell_data(platform_center) != null and grid.get_cell_data(platform_center).can_stop, "Platform top is regular walkable terrain")
	check(not grid.get_cell_data(Vector3i(6, 0, 2)).walkable, "Platform body blocks its ground footprint")
	check(grid.world_to_grid(grid.grid_to_world(platform_center)) == platform_center, "Platform clicks resolve to the elevated cell")
	check(grid.map_data.traversal_links.size() == 1, "The authored ladder becomes reusable MapData")
	check(battle.pathfinder.calculate_3d_path(ladder_bottom, ladder_top).size() == 2, "Ladder explicitly connects its floor and platform cells")
	check(not battle.pathfinder.calculate_3d_path(ladder_bottom, platform_center).is_empty(), "Platform uses normal pathfinding after the ladder")

	for unit in level.turn_manager.player_units + level.turn_manager.enemy_units:
		var spawn_cell = grid.world_to_grid(unit.global_position)
		check(grid.map_data.has_cell(spawn_cell), "%s spawns inside the map" % unit.name)
		check(grid.get_cell_data(spawn_cell).can_stop, "%s spawns on valid floor" % unit.name)

	for player in level.turn_manager.player_units:
		for enemy in level.turn_manager.enemy_units:
			var start = grid.world_to_grid(player.global_position)
			var target = grid.world_to_grid(enemy.global_position)
			check(not battle.pathfinder.calculate_3d_path(start, target).is_empty(), "%s can reach %s" % [player.name, enemy.name])

	for route in [Vector3(0.5, 0, -9.5), Vector3(0.5, 0, 0.5), Vector3(0.5, 0, 9.5)]:
		check(grid.get_cell_data(grid.world_to_grid(route)).can_stop, "North, center, and south crossings remain open")

	level.queue_free()
	await process_frame
	print("Battlefield layout smoke: %d failure(s)" % failures)
	quit(1 if failures else 0)
