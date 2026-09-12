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
	await create_timer(0.2).timeout

	var battle: BattleController = level.battle_controller
	var map_data: MapData = battle.grid_manager.map_data
	var pathfinder: Pathfinder = battle.pathfinder
	var requirements := {
		TacticalUnit.Faction.PLAYER: 5,
		TacticalUnit.Faction.ENEMY: 5,
	}
	check(battle.last_map_validation != null and battle.last_map_validation.is_valid(), "The handmade battlefield passes validation before battle starts")
	check(map_data.get_spawn_cells(TacticalUnit.Faction.PLAYER).size() == 5, "Player SpawnZone contributes five MapData cells")
	check(map_data.get_spawn_cells(TacticalUnit.Faction.ENEMY).size() == 5, "Enemy SpawnZone contributes five MapData cells")
	check(map_data.get_total_spawn_count() == 15, "Validation summary counts all faction spawn cells")

	var sample_cell: MapCellData = map_data.get_cell(Vector3i(0, 0, 0))
	var original_cost := sample_cell.movement_cost
	sample_cell.movement_cost = 0
	var bad_cost := MapValidator.validate(map_data, pathfinder, requirements)
	check(not bad_cost.is_valid() and bad_cost.has_code("INVALID_MOVEMENT_COST"), "Movement costs below one are rejected with a stable issue code")
	sample_cell.movement_cost = original_cost

	var bad_link := TraversalLinkData.new(Vector3i(0, 0, 0), Vector3i(999, 9, 999))
	map_data.add_traversal_link(bad_link)
	var missing_endpoint := MapValidator.validate(map_data, pathfinder, requirements)
	check(missing_endpoint.has_code("TRAVERSAL_ENDPOINT_MISSING"), "Traversal links cannot end outside MapData")
	map_data.traversal_links.pop_back()

	var shared_spawn: Vector3i = map_data.get_spawn_cells(TacticalUnit.Faction.PLAYER)[0]
	map_data.add_spawn_cell(TacticalUnit.Faction.ENEMY, shared_spawn)
	var duplicate_spawn := MapValidator.validate(map_data, pathfinder, requirements)
	check(duplicate_spawn.has_code("DUPLICATE_SPAWN"), "Spawn positions must be unique across factions")
	map_data.spawn_cells[TacticalUnit.Faction.ENEMY].pop_back()

	var insufficient := MapValidator.validate(map_data, pathfinder, {TacticalUnit.Faction.PLAYER: 6, TacticalUnit.Faction.ENEMY: 5})
	check(insufficient.has_code("INSUFFICIENT_SPAWNS"), "Requested team sizes must fit their spawn data")

	var isolated_spawn: Vector3i = map_data.get_spawn_cells(TacticalUnit.Faction.PLAYER)[0]
	var isolated_id: int = pathfinder.grid_to_id_map[isolated_spawn]
	pathfinder.astar.set_point_disabled(isolated_id, true)
	var disconnected := MapValidator.validate(map_data, pathfinder, requirements)
	check(disconnected.has_code("SPAWNS_DISCONNECTED"), "Disconnected opposing spawns invalidate a battlefield")
	pathfinder.astar.set_point_disabled(isolated_id, false)

	var final_result := MapValidator.validate(map_data, pathfinder, requirements)
	check(final_result.is_valid(), "Restoring corrupted data returns the map to a valid state")
	check(final_result.describe() == "Map validation passed", "Validation results provide readable summaries")

	level.queue_free()
	await process_frame
	print("Map validation smoke: %d failure(s)" % failures)
	quit(1 if failures else 0)
