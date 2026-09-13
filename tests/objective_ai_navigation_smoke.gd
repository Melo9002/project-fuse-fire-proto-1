extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	await _check_automated_player_reaches_zone()
	await _check_automated_player_extracts()
	await _check_ally_extracts()
	print("Objective AI navigation smoke: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _create_level(kind: MissionObjectiveDefinition.Kind, allies := 0) -> BattleLevel:
	var level := load("res://levels/prototype_map/prototype_map.tscn").instantiate() as BattleLevel
	level.configure(1, 1, false, 1, allies, Vector2i(32, 24), false, MissionActor.VIPBehavior.PLAYER_CONTROLLED, MissionCatalog.create_mission(kind, 1))
	root.add_child(level)
	await create_timer(0.2).timeout
	return level

func _nearby_destination(level: BattleLevel, unit: TacticalUnit) -> Vector3i:
	var grid := level.battle_controller.grid_manager
	var start := grid.get_unit_grid(unit)
	var reachable := level.battle_controller.pathfinder.get_reachable_cells(start, unit.stats.speed)
	reachable.sort_custom(func(a: Vector3i, b: Vector3i): return start.distance_squared_to(a) < start.distance_squared_to(b))
	for cell in reachable:
		if grid.can_unit_occupy_cell(unit, cell):
			return cell
	return Vector3i(-1, -1, -1)

func _wait_until(predicate: Callable, seconds := 5.0) -> void:
	var ticks := ceili(seconds / 0.05)
	for tick in ticks:
		if predicate.call():
			return
		await create_timer(0.05).timeout

func _check_automated_player_reaches_zone() -> void:
	var level := await _create_level(MissionObjectiveDefinition.Kind.REACH)
	var player := level.turn_manager.player_units[0]
	var destination := _nearby_destination(level, player)
	check(destination.x >= 0, "Reach AI test has a nearby legal destination")
	level.battle_controller.grid_manager.map_data.set_objective_zone(&"reach", [destination])
	level.battle_controller.set_debug_player_ai(true)
	await _wait_until(func(): return level.turn_manager.battle_result != TurnManager.BattleResult.ONGOING)
	check(level.turn_manager.battle_result == TurnManager.BattleResult.VICTORY, "AI-controlled player completes a Reach objective")
	check(level.objective_manager.get_objective(&"reach").is_completed(), "Reach movement updates shared objective state")
	level.queue_free()
	await process_frame

func _check_ally_extracts() -> void:
	var level := await _create_level(MissionObjectiveDefinition.Kind.EXTRACT, 1)
	var ally := level.turn_manager.allied_units[0]
	var destination := _nearby_destination(level, ally)
	check(destination.x >= 0, "Extract AI test has a nearby legal destination")
	level.battle_controller.grid_manager.map_data.set_objective_zone(&"extract", [destination])
	level.turn_manager.end_current_turn()
	await _wait_until(func(): return level.turn_manager.allied_units.is_empty() and level.turn_manager.current_phase == TurnManager.TurnPhase.ENEMY_TURN)
	check(level.turn_manager.allied_units.is_empty(), "AI ally leaves the roster after extraction")
	check(level.objective_manager.extracted_units == 1, "AI ally uses the shared ExtractAction and updates mission progress")
	check(not level.battle_controller.grid_manager.occupancy_map.values().has(ally), "Extracted AI ally releases its occupied cell")
	check(level.turn_manager.current_phase == TurnManager.TurnPhase.ENEMY_TURN, "Ally extraction advances the activation queue exactly once")
	level.queue_free()
	await process_frame

func _check_automated_player_extracts() -> void:
	var level := await _create_level(MissionObjectiveDefinition.Kind.EXTRACT)
	var player := level.turn_manager.player_units[0]
	var destination := _nearby_destination(level, player)
	check(destination.x >= 0, "Player extraction AI test has a nearby legal destination")
	level.battle_controller.grid_manager.map_data.set_objective_zone(&"extract", [destination])
	level.battle_controller.set_debug_player_ai(true)
	await _wait_until(func(): return level.turn_manager.battle_result != TurnManager.BattleResult.ONGOING)
	check(level.turn_manager.battle_result == TurnManager.BattleResult.VICTORY, "AI-controlled player can finish an extraction mission")
	check(level.objective_manager.extracted_units == 1, "AI-controlled player uses the shared ExtractAction")
	check(level.turn_manager.player_units.is_empty(), "Extracted automated player leaves the turn roster")
	level.queue_free()
	await process_frame
