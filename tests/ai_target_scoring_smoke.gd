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
	level.configure(1, 2, false, 1, 1, Vector2i(32, 24), false, MissionActor.VIPBehavior.PLAYER_CONTROLLED, MissionCatalog.create_mission(MissionObjectiveDefinition.Kind.ENEMY_EVACUATION, 2))
	root.add_child(level)
	await create_timer(0.2).timeout
	var grid := level.battle_controller.grid_manager
	var player := level.turn_manager.player_units[0]
	var ally := level.turn_manager.allied_units[0]
	var first := level.turn_manager.enemy_units[0]
	var second := level.turn_manager.enemy_units[1]
	var friendlies: Array[TacticalUnit] = [player, ally]
	var normal := AIDifficultyPolicy.create(AIDifficultyPolicy.Tier.NORMAL)
	var easy := AIDifficultyPolicy.create(AIDifficultyPolicy.Tier.EASY)
	var hard := AIDifficultyPolicy.create(AIDifficultyPolicy.Tier.HARD)
	var context := SquadContext.new()
	var intent := level.objective_manager.get_mission_intent(player)

	var healthy := AITargetScorer.evaluate(player, first, friendlies, intent, level.objective_manager, grid, normal, context)
	first.stats.current_hp = 25
	var wounded := AITargetScorer.evaluate(player, first, friendlies, intent, level.objective_manager, grid, normal, context)
	check(wounded.vulnerability > healthy.vulnerability, "Wounded and near-defeat targets gain priority")
	first.stats.current_hp = 100
	second.mission_actor.kind = MissionActor.Kind.VIP
	var vip_score := AITargetScorer.evaluate(player, second, friendlies, intent, level.objective_manager, grid, normal, context)
	check(vip_score.vip > 0.0, "Hostile VIPs receive an explicit score bonus")
	check(AITargetScorer.evaluate(player, second, friendlies, intent, level.objective_manager, grid, hard, context).vip > vip_score.vip, "Hard weighs VIPs more strongly")
	check(AITargetScorer.evaluate(player, second, friendlies, intent, level.objective_manager, grid, easy, context).vip < vip_score.vip, "Easy weighs VIPs less strongly")
	context.reserve_target(ally, second)
	check(AITargetScorer.evaluate(player, second, friendlies, intent, level.objective_manager, grid, normal, context).focus < 0.0, "Squad focus still reduces target priority")
	context.begin_round(1)

	var exit_cell := Vector3i(-1, -1, -1)
	for cell in grid.map_data.get_objective_zone(&"enemy_extract"):
		if grid.can_unit_occupy_cell(first, cell):
			exit_cell = cell
			break
	check(exit_cell.x >= 0, "Enemy evacuation has a free exit cell for urgency testing")
	if exit_cell.x >= 0:
		_relocate(grid, first, exit_cell)
		var escape_score := AITargetScorer.evaluate(player, first, friendlies, intent, level.objective_manager, grid, normal, context)
		check(escape_score.mission >= 30.0, "An enemy at its exit becomes an urgent mission target")

	var legal_cells: Array[Vector3i] = []
	var player_cell := grid.get_unit_grid(player)
	for cell in grid.map_data.cells:
		if not grid.can_unit_occupy_cell(first, cell):
			continue
		if player_cell.distance_to(cell) > 5.0:
			continue
		var old := grid.get_unit_grid(first)
		_relocate(grid, first, cell)
		if level.battle_controller.evaluate_attack(player, first).is_legal:
			legal_cells.append(cell)
		_relocate(grid, first, old)
		if legal_cells.size() >= 2:
			break
	check(legal_cells.size() >= 2, "Found two legal attack targets for selection testing")
	if legal_cells.size() >= 2:
		_relocate(grid, first, legal_cells[0])
		_relocate(grid, second, legal_cells[1])
		second.attack_range = 10
		var threat_score := AITargetScorer.evaluate(player, second, friendlies, intent, level.objective_manager, grid, normal, context)
		check(threat_score.threat > 0.0, "An enemy able to shoot friendlies gains threat priority")
		var ai := level.player_units_parent.get_node("PlayerUnit1AI") as AIController
		ai.current_mission_intent = MissionIntent.new(MissionIntent.Kind.NONE)
		check(ai._find_attack_target() == second, "AI chooses the higher-scored hostile VIP when both shots are legal")
		ally.mission_actor.kind = MissionActor.Kind.VIP
		ally.mission_actor.mission_id = &"FriendlyVIP"
		level.objective_manager.load_mission(MissionCatalog.create_mission(MissionObjectiveDefinition.Kind.PROTECT, 2, true))
		var protect_intent := level.objective_manager.get_mission_intent(player)
		var protect_score := AITargetScorer.evaluate(player, second, friendlies, protect_intent, level.objective_manager, grid, normal, context)
		check(protect_score.mission > 0.0, "A target threatening the protected VIP gains mission priority")
		level.objective_manager.load_mission(MissionCatalog.create_mission(MissionObjectiveDefinition.Kind.RESCUE, 2))
		var carried_vip := TacticalUnit.new()
		ally.carry_unit(carried_vip)
		var enemy_friendlies: Array[TacticalUnit] = [first, second]
		var carrier_score := AITargetScorer.evaluate(first, ally, enemy_friendlies, MissionIntent.new(), level.objective_manager, grid, normal, context)
		check(carrier_score.mission >= 25.0, "Enemy AI treats a rescue carrier as a high-value mission target")
		carried_vip.free()

	level.queue_free()
	await process_frame
	print("AI target scoring smoke: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _relocate(grid: GridManager, unit: TacticalUnit, cell: Vector3i) -> void:
	var old := grid.get_unit_grid(unit)
	grid.update_unit_position(unit, old, cell)
	unit.global_position = grid.grid_to_world(cell) + Vector3.UP * unit.standing_height
