extends Node
class_name AIController

@export var unit: TacticalUnit
@export var turn_manager: TurnManager
@export var battle_controller: BattleController

func _ready() -> void:
	if not _validate_dependencies():
		return
	turn_manager.active_unit_changed.connect(_on_active_unit_changed)
	unit.defeated.connect(_on_unit_defeated)

func _validate_dependencies() -> bool:
	var valid := true
	if not unit:
		push_error("AIController on '%s' is missing its 'unit' target reference!" % get_path())
		valid = false
	if not turn_manager:
		push_error("AIController on '%s' is missing its 'turn_manager' reference!" % get_path())
		valid = false
	if not battle_controller:
		push_error("AIController on '%s' is missing its 'battle_controller' reference!" % get_path())
		valid = false
	return valid

func _on_active_unit_changed(new_active_unit: TacticalUnit) -> void:
	if new_active_unit != unit:
		return

	if turn_manager.current_phase != TurnManager.TurnPhase.ENEMY_TURN:
		return

	print_rich("[color=magenta][AI][/color] Activated enemy unit: [b]%s[/b]" % unit.name)
	_execute_turn()

func _execute_turn() -> void:
	# Brief pause makes the enemy activation visible before it acts.
	await get_tree().create_timer(0.6).timeout
	var has_moved := false
	while is_instance_valid(unit) and unit.stats.current_ap > 0 \
		and turn_manager.battle_result == TurnManager.BattleResult.ONGOING:
		var attack_target = _find_attack_target()
		if attack_target and battle_controller.try_attack(unit, attack_target):
			await get_tree().create_timer(0.25).timeout
			continue
		var movement_target = _find_nearest_player()
		if not has_moved and movement_target and await _move_toward(movement_target):
			has_moved = true
			continue
		battle_controller.try_defend(unit)
		break

	turn_manager.end_current_turn()

func _move_toward(target: TacticalUnit) -> bool:
	var start_cell = battle_controller.grid_manager.get_unit_grid(unit)
	var target_cell = battle_controller.grid_manager.get_unit_grid(target)
	var path = battle_controller.pathfinder.calculate_3d_path(start_cell, target_cell)
	if path.size() <= 1:
		return false

	# Choose the farthest legal stop along the route.
	path.remove_at(path.size() - 1)
	var reachable = battle_controller.pathfinder.get_reachable_cells(start_cell, unit.stats.speed)
	var destination_index = path.size() - 1
	while destination_index > 0:
		var candidate = battle_controller.world_to_grid(path[destination_index])
		if reachable.has(candidate) and battle_controller.grid_manager.can_unit_occupy_cell(unit, candidate):
			if await battle_controller.try_move(unit, candidate):
				return true
		destination_index -= 1
	return false

func _find_attack_target() -> TacticalUnit:
	var best_target: TacticalUnit
	var lowest_hp := INF
	for candidate in turn_manager.player_units:
		if not is_instance_valid(candidate) or not candidate.stats or candidate.stats.is_defeated:
			continue
		if battle_controller.evaluate_attack(unit, candidate).is_legal and candidate.stats.current_hp < lowest_hp:
			best_target = candidate
			lowest_hp = candidate.stats.current_hp
	return best_target

func _find_nearest_player() -> TacticalUnit:
	var nearest: TacticalUnit
	var nearest_distance := INF
	for candidate in turn_manager.player_units:
		if not is_instance_valid(candidate) or not candidate.stats or candidate.stats.is_defeated:
			continue
		var distance = unit.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

func _on_unit_defeated(_defeated_unit: TacticalUnit) -> void:
	queue_free()
