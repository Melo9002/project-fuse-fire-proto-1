extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	await _check_automated_player()
	await _check_ally()
	await _check_enemy_without_mission_goal()
	print("AI second advance smoke: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _check_automated_player() -> void:
	var level := load("res://levels/prototype_map/prototype_map.tscn").instantiate() as BattleLevel
	level.configure(1, 1, false, 1, 0, Vector2i(32, 24), false, MissionActor.VIPBehavior.PLAYER_CONTROLLED, MissionCatalog.create_mission(MissionObjectiveDefinition.Kind.REACH, 1))
	root.add_child(level)
	await create_timer(0.2).timeout
	var player := level.turn_manager.player_units[0]
	var ai := level.player_units_parent.get_node("PlayerUnit1AI") as AIController
	var grid := level.battle_controller.grid_manager
	var start := grid.get_unit_grid(player)
	var exposed_cell := Vector3i(-1, -1, -1)
	for cell in grid.map_data.cells:
		if grid.can_unit_occupy_cell(player, cell) and not ai._is_safe_advance_cell(cell):
			exposed_cell = cell
			break
	_check(exposed_cell.x >= 0, "Found an exposed destination near the enemy")
	if exposed_cell.x >= 0:
		_check(not ai._is_safe_advance_cell(exposed_cell), "Second-advance safety rejects an enemy firing lane")
	var destination := Vector3i(-1, -1, -1)
	for cell in grid.map_data.cells:
		if not grid.can_unit_occupy_cell(player, cell):
			continue
		var path := level.battle_controller.pathfinder.calculate_3d_path(start, cell)
		if path.size() > player.stats.speed + 2 and path.size() <= player.stats.speed * 2 + 1 and ai._is_safe_advance_cell(cell):
			destination = cell
			break
	_check(destination.x >= 0, "Found a reachable safe destination that takes two moves")
	if destination.x >= 0:
		grid.map_data.set_objective_zone(&"reach", [destination])
		level.battle_controller.set_debug_player_ai(true)
		await _wait_until(func(): return level.turn_manager.battle_result != TurnManager.BattleResult.ONGOING or level.turn_manager.current_phase != TurnManager.TurnPhase.PLAYER_TURN)
		_check(level.turn_manager.battle_result == TurnManager.BattleResult.VICTORY, "AI spends its second AP to reach a safe objective")
	level.queue_free()
	await process_frame

func _check_ally() -> void:
	var level := load("res://levels/prototype_map/prototype_map.tscn").instantiate() as BattleLevel
	level.configure(1, 1, false, 1, 1, Vector2i(32, 24), false, MissionActor.VIPBehavior.PLAYER_CONTROLLED, MissionCatalog.create_mission(MissionObjectiveDefinition.Kind.REACH, 1))
	root.add_child(level)
	await create_timer(0.2).timeout
	var ally := level.turn_manager.allied_units[0]
	var ai := level.allied_units_parent.get_node("AllyUnit1AI") as AIController
	var grid := level.battle_controller.grid_manager
	var start := grid.get_unit_grid(ally)
	var destination := Vector3i(-1, -1, -1)
	for cell in grid.map_data.cells:
		if not grid.can_unit_occupy_cell(ally, cell):
			continue
		var path := level.battle_controller.pathfinder.calculate_3d_path(start, cell)
		if path.size() > ally.stats.speed + 2 and path.size() <= ally.stats.speed * 2 + 1 and ai._is_safe_advance_cell(cell):
			destination = cell
			break
	_check(destination.x >= 0, "Found a two-move destination for an AI ally")
	if destination.x >= 0:
		grid.map_data.set_objective_zone(&"reach", [destination])
		level.turn_manager.end_current_turn()
		await _wait_until(func(): return level.turn_manager.battle_result != TurnManager.BattleResult.ONGOING or level.turn_manager.current_phase == TurnManager.TurnPhase.ENEMY_TURN)
		_check(level.turn_manager.battle_result == TurnManager.BattleResult.VICTORY, "AI ally uses its second AP to reach a safe objective")
	level.queue_free()
	await process_frame

func _check_enemy_without_mission_goal() -> void:
	var level := load("res://levels/prototype_map/prototype_map.tscn").instantiate() as BattleLevel
	level.configure(1, 1, false, 1, 0, Vector2i(32, 24), false, MissionActor.VIPBehavior.PLAYER_CONTROLLED, MissionCatalog.create_mission(MissionObjectiveDefinition.Kind.REACH, 1))
	root.add_child(level)
	await create_timer(0.2).timeout
	var enemy := level.turn_manager.enemy_units[0]
	var grid := level.battle_controller.grid_manager
	var start := grid.get_unit_grid(enemy)
	level.turn_manager.end_current_turn()
	await _wait_until(func(): return level.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_TURN or level.turn_manager.battle_result != TurnManager.BattleResult.ONGOING)
	var end := grid.get_unit_grid(enemy)
	var traveled_path := level.battle_controller.pathfinder.calculate_3d_path(start, end)
	_check(traveled_path.size() > enemy.stats.speed + 1, "Enemy with no mission goal uses two safe moves toward the player")
	level.queue_free()
	await process_frame

func _wait_until(predicate: Callable) -> void:
	for tick in 160:
		if predicate.call():
			return
		await create_timer(0.05).timeout
