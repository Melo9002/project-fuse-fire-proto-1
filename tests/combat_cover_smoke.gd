extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func place(unit: TacticalUnit, cell: Vector3i, grid: GridManager) -> void:
	unit.global_position = grid.grid_to_world(cell) + Vector3.UP
	grid.update_unit_position(unit, grid.get_unit_grid(unit), cell)

func _run() -> void:
	var level = load("res://levels/prototype_map/prototype_map.tscn").instantiate()
	root.add_child(level)
	await create_timer(0.15).timeout

	var battle: BattleController = level.get_node("Systems/BattleController")
	var grid = battle.grid_manager
	var attacker = battle.turn_manager.player_units[0]
	var target = battle.turn_manager.enemy_units[0]
	check(attacker.attack_range == 8, "Friendly units use the extended test range")
	check(target.attack_range == 3, "Enemy attack range remains unchanged")
	var mismatches := 0
	var small_block = grid.get_cell_data(Vector3i(14, 0, 12))
	place(attacker, Vector3i(13, 0, 12), grid)
	place(target, Vector3i(15, 0, 12), grid)
	check(battle.evaluate_attack(attacker, target).hit_chance == 50, "Small authored block permits a 50 percent shot")
	check(level.get_node("Environment/Obstacles/CentralLowBlock").size.y == small_block.cover_height, "Small block height matches metadata")
	# Include full cover in the exhaustive LOS comparison.
	small_block.blocks_line_of_sight = true
	grid.map_data.rebuild_los_index()
	for source in grid.map_data.cells:
		if not grid.get_cell_data(source).walkable:
			continue
		place(attacker, source, grid)
		for destination in grid.map_data.cells:
			if not grid.get_cell_data(destination).walkable or source == destination:
				continue
			place(target, destination, grid)
			var floor_visible = CombatRules.has_line_of_sight_to_position(attacker, grid.grid_to_world(destination), grid, battle.get_world_3d())
			var unit_visible = CombatRules.has_line_of_sight_to_position(attacker, target.global_position, grid, battle.get_world_3d())
			if floor_visible != unit_visible:
				if mismatches == 0:
					print("First LOS mismatch: ", source, " -> ", destination, " floor=", floor_visible, " unit=", unit_visible)
				mismatches += 1
	check(mismatches == 0, "Floor and unit LOS must agree for every walkable cell pair: %d mismatches" % mismatches)
	var corner_blocker = grid.get_cell_data(Vector3i(2, 0, 2))
	corner_blocker.blocks_line_of_sight = true
	corner_blocker.cover_height = 2.0
	grid.map_data.rebuild_los_index()
	place(attacker, Vector3i(1, 0, 2), grid)
	place(target, Vector3i(2, 0, 1), grid)
	check(battle.evaluate_attack(attacker, target).is_legal, "Touching a full-cover corner alone permits a shot")
	place(target, Vector3i(3, 0, 2), grid)
	check(not battle.evaluate_attack(attacker, target).is_legal, "Crossing the interior of full cover blocks a shot")
	corner_blocker.blocks_line_of_sight = false
	corner_blocker.cover_height = 0.0
	grid.map_data.rebuild_los_index()

	# The z=6 low barrier protects only the side facing the attacker.
	place(attacker, Vector3i(5, 0, 4), grid)
	place(target, Vector3i(5, 0, 7), grid)
	var low_cover = battle.evaluate_attack(attacker, target)
	check(low_cover.is_legal, "Low cover keeps the attack legal")
	check(low_cover.hit_chance == 50, "Directional low cover gives 50 percent hit chance")
	check(low_cover.cover_type == MapCellData.CoverType.LOW, "Evaluation reports low cover")
	var low_cover_cell = Vector3i(5, 0, 6)
	check(not battle.pathfinder.astar.is_point_disabled(battle.pathfinder.grid_to_id_map[low_cover_cell]), "Low cover remains connected for vault paths")
	check(not grid.get_cell_data(low_cover_cell).can_stop, "Units cannot end movement on low cover")
	check(CombatRules.has_line_of_sight_to_position(attacker, target.global_position, grid, battle.get_world_3d()), "Unwalkable low cover does not block a shot")
	check(CombatRules.has_line_of_sight_to_position(attacker, grid.grid_to_world(Vector3i(5, 0, 7)), grid, battle.get_world_3d()), "Attack preview and target checks share line of sight")

	place(attacker, Vector3i(5, 0, 8), grid)
	var wrong_side = battle.evaluate_attack(attacker, target)
	check(wrong_side.is_legal and wrong_side.hit_chance == 100, "Cover does not protect the wrong side")

	attacker.attack_range = 6
	place(attacker, Vector3i(10, 0, 4), grid)
	place(target, Vector3i(14, 0, 4), grid)
	var full_cover = battle.evaluate_attack(attacker, target)
	check(not full_cover.is_legal and full_cover.reason == "Blocked", "Full cover makes the shot illegal")

	place(attacker, Vector3i(10, 0, 9), grid)
	place(target, Vector3i(14, 0, 9), grid)
	var wall_edge = battle.evaluate_attack(attacker, target)
	check(wall_edge.is_legal and wall_edge.hit_chance == 100, "A shot past the wall edge remains legal")

	attacker.stats.current_ap = attacker.stats.max_ap
	small_block.blocks_line_of_sight = false
	grid.map_data.rebuild_los_index()
	target.stats.current_hp = target.stats.max_hp
	var forced_miss = AttackAction.new(attacker, target, 1, 50, 75.0)
	check(forced_miss.execute() and not forced_miss.did_hit, "A failed hit roll performs a miss")
	check(target.stats.current_hp == target.stats.max_hp and attacker.stats.current_ap == 1, "A miss deals no damage and spends AP")
	var forced_hit = AttackAction.new(attacker, target, 1, 50, 25.0)
	check(forced_hit.execute() and forced_hit.did_hit, "A successful hit roll performs a hit")
	check(target.stats.current_hp == target.stats.max_hp - 25 and attacker.stats.current_ap == 0, "A hit deals full damage and spends AP")

	level.queue_free()
	await process_frame
	print("Combat cover smoke: %d failure(s)" % failures)
	quit(1 if failures else 0)
