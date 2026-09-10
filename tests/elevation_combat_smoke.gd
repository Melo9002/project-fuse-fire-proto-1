extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func place(unit: TacticalUnit, cell: Vector3i, grid: GridManager) -> void:
	unit.global_position = grid.grid_to_world(cell) + Vector3.UP * unit.standing_height
	grid.update_unit_position(unit, grid.get_unit_grid(unit), cell)

func _run() -> void:
	var level = load("res://levels/prototype_map/prototype_map.tscn").instantiate() as BattleLevel
	level.configure(1, 1)
	root.add_child(level)
	await create_timer(0.15).timeout

	var battle = level.battle_controller
	var grid = battle.grid_manager
	var attacker: TacticalUnit = level.turn_manager.player_units[0]
	var target: TacticalUnit = level.turn_manager.enemy_units[0]
	attacker.attack_range = 20
	target.attack_range = 20

	var ladder_bottom := Vector3i(5, 0, 4)
	var ladder_top := Vector3i(5, 2, 3)
	place(attacker, ladder_bottom, grid)
	place(target, ladder_top, grid)
	check(battle.evaluate_attack(attacker, target).is_legal, "A ground unit can see a target at the platform edge")
	check(CombatRules.has_line_of_sight_to_position(attacker, grid.grid_to_world(ladder_top), grid, battle.get_world_3d()), "Elevated attack preview matches target validation")

	place(attacker, Vector3i(7, 2, 2), grid)
	place(target, Vector3i(15, 0, 2), grid)
	check(not battle.evaluate_attack(attacker, target).is_legal, "A descending shot through a full-height wall is blocked")

	var elevated_target := Vector3i(15, 2, 2)
	grid.map_data.add_cell(MapCellData.new(elevated_target, grid.grid_to_world(elevated_target)))
	place(target, elevated_target, grid)
	check(battle.evaluate_attack(attacker, target).is_legal, "A level shot above a wall remains legal")

	var target_above_low_cover := Vector3i(5, 2, 7)
	grid.map_data.add_cell(MapCellData.new(target_above_low_cover, grid.grid_to_world(target_above_low_cover)))
	place(attacker, Vector3i(5, 0, 4), grid)
	place(target, target_above_low_cover, grid)
	var elevated_cover = battle.evaluate_attack(attacker, target)
	check(elevated_cover.is_legal and elevated_cover.hit_chance == 100, "Ground-level low cover does not protect an elevated target")

	level.queue_free()
	await process_frame
	print("Elevation combat smoke: %d failure(s)" % failures)
	quit(1 if failures else 0)
