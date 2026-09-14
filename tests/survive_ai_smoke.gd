extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _wait_until(predicate: Callable, seconds := 6.0) -> void:
	for tick in ceili(seconds / 0.05):
		if predicate.call():
			return
		await create_timer(0.05).timeout

func _run() -> void:
	var level := load("res://levels/prototype_map/prototype_map.tscn").instantiate() as BattleLevel
	level.configure(1, 1, false, 1, 1, Vector2i(32, 24), false, MissionActor.VIPBehavior.PLAYER_CONTROLLED, MissionCatalog.create_mission(MissionObjectiveDefinition.Kind.SURVIVE, 1))
	root.add_child(level)
	await create_timer(0.2).timeout

	var ally := level.turn_manager.allied_units[0]
	var start := ally.grid_position
	level.battle_controller.set_debug_enemy_control(true)
	level.battle_controller.grid_manager.map_data.set_objective_zone(&"extract", [start])
	level.turn_manager.end_current_turn()
	await _wait_until(func(): return level.turn_manager.current_phase == TurnManager.TurnPhase.ENEMY_TURN)

	check(level.turn_manager.allied_units.has(ally), "Survival AI cannot extract before the timer completes")
	check(level.objective_manager.extracted_units == 0, "Early survival movement records no extraction")
	check(ally.grid_position != start, "Survival AI repositions while waiting for the timer")

	level.objective_manager.complete_objective(&"survive")
	level.battle_controller.grid_manager.map_data.set_objective_zone(&"extract", [ally.grid_position])
	level.turn_manager.end_current_turn()
	level.turn_manager.end_current_turn()
	await _wait_until(func(): return level.turn_manager.allied_units.is_empty())

	check(level.objective_manager.extracted_units == 1, "Survival AI evacuates after the timer completes")
	check(level.objective_manager.get_objective(&"extract_units").progress == 1, "Post-timer AI extraction advances the shared survivor objective")
	print("Survive AI smoke: %d failure(s)" % failures)
	level.queue_free()
	await process_frame
	quit(1 if failures else 0)
