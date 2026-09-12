extends Node
class_name AIController

@export var unit: TacticalUnit
@export var turn_manager: TurnManager
@export var battle_controller: BattleController

var _is_executing: bool = false
var _last_move_destination := Vector3i.ZERO

func _ready() -> void:
	if not _validate_dependencies():
		return
	turn_manager.active_unit_changed.connect(_on_active_unit_changed)
	battle_controller.debug_enemy_control_changed.connect(_on_debug_enemy_control_changed)
	battle_controller.debug_player_ai_changed.connect(_on_debug_player_ai_changed)
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

	if not _should_control_unit():
		return

	print_rich("[color=magenta][AI][/color] Activated unit: [b]%s[/b]" % unit.name)
	_execute_turn()

func _execute_turn() -> void:
	if _is_executing:
		return
	_is_executing = true
	# Brief pause makes the enemy activation visible before it acts.
	await get_tree().create_timer(0.6).timeout
	if not _should_control_unit():
		_is_executing = false
		return
	var has_moved := false
	while is_instance_valid(unit) and unit.stats.current_ap > 0 \
		and turn_manager.battle_result == TurnManager.BattleResult.ONGOING \
		and _should_control_unit():
		var attack_target = _find_attack_target()
		if attack_target and battle_controller.try_attack(unit, attack_target):
			battle_controller.record_ai_decision(unit, "Attack", attack_target.name, "Legal shot; target has the lowest HP among legal targets.", "Move, Defend")
			await get_tree().create_timer(0.25).timeout
			continue
		var movement_target = _find_nearest_hostile()
		if not has_moved and movement_target and await _move_toward(movement_target):
			has_moved = true
			battle_controller.record_ai_decision(unit, "Move", str(_last_move_destination), "No legal shot; approached the nearest hostile unit.", "Attack, Defend")
			continue
		if battle_controller.try_defend(unit):
			var reason := "No legal shot after moving." if has_moved else "No legal shot or reachable approach."
			battle_controller.record_ai_decision(unit, "Defend", unit.name, reason, "Attack, Move")
		break

	if _should_control_unit():
		if turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_TURN:
			turn_manager.advance_automated_player(unit)
		else:
			turn_manager.end_current_turn()
	_is_executing = false

func _on_debug_enemy_control_changed(enabled: bool) -> void:
	if not enabled and turn_manager.current_phase == TurnManager.TurnPhase.ENEMY_TURN \
		and turn_manager.active_unit == unit:
		_execute_turn()

func _on_debug_player_ai_changed(enabled: bool) -> void:
	if enabled and turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_TURN \
		and turn_manager.active_unit == unit:
		_execute_turn()

func _should_control_unit() -> bool:
	if not is_instance_valid(unit) or turn_manager.active_unit != unit:
		return false
	if turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_TURN:
		return unit.faction == TacticalUnit.Faction.PLAYER and battle_controller.debug_player_ai
	if turn_manager.current_phase == TurnManager.TurnPhase.ALLY_TURN:
		return unit.faction == TacticalUnit.Faction.ALLY
	if turn_manager.current_phase == TurnManager.TurnPhase.ENEMY_TURN:
		return unit.faction == TacticalUnit.Faction.ENEMY and not battle_controller.debug_enemy_control
	return false

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
				_last_move_destination = candidate
				return true
		destination_index -= 1
	return false

func _find_attack_target() -> TacticalUnit:
	var best_target: TacticalUnit
	var lowest_hp := INF
	for candidate in _get_hostile_units():
		if not is_instance_valid(candidate) or not candidate.stats or candidate.stats.is_defeated:
			continue
		if battle_controller.evaluate_attack(unit, candidate).is_legal and candidate.stats.current_hp < lowest_hp:
			best_target = candidate
			lowest_hp = candidate.stats.current_hp
	return best_target

func _find_nearest_hostile() -> TacticalUnit:
	var nearest: TacticalUnit
	var nearest_distance := INF
	for candidate in _get_hostile_units():
		if not is_instance_valid(candidate) or not candidate.stats or candidate.stats.is_defeated:
			continue
		var distance = unit.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

func _get_hostile_units() -> Array[TacticalUnit]:
	var hostile_units: Array[TacticalUnit] = []
	for candidate in turn_manager.player_units + turn_manager.allied_units + turn_manager.enemy_units:
		if is_instance_valid(candidate) and FactionRules.are_hostile(unit.faction, candidate.faction):
			hostile_units.append(candidate)
	return hostile_units

func _on_unit_defeated(_defeated_unit: TacticalUnit) -> void:
	queue_free()
