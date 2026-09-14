extends Node
class_name AIController

const MissionIntentData = preload("res://systems/objectives/mission_intent.gd")

@export var unit: TacticalUnit
@export var turn_manager: TurnManager
@export var battle_controller: BattleController

var _is_executing: bool = false
var _last_move_destination := Vector3i.ZERO
var _objective_manager: ObjectiveManager
var _squad_context: SquadContext
var _squad_notes: Array[String] = []
var _pending_target_note := ""
var current_mission_intent := MissionIntentData.new()

enum MissionStepResult {
	NONE,
	MOVED,
	INTERACTED,
	EXTRACTED,
}

func _ready() -> void:
	if not _validate_dependencies():
		return
	turn_manager.active_unit_changed.connect(_on_active_unit_changed)
	battle_controller.debug_enemy_control_changed.connect(_on_debug_enemy_control_changed)
	battle_controller.debug_player_ai_changed.connect(_on_debug_player_ai_changed)
	unit.defeated.connect(_on_unit_defeated)
	_objective_manager = get_tree().get_first_node_in_group("objective_manager") as ObjectiveManager

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
	current_mission_intent = _objective_manager.get_mission_intent(unit) if _objective_manager else MissionIntentData.new()
	_squad_context = battle_controller.get_squad_context(unit)
	_squad_context.begin_unit(unit)
	_squad_notes.clear()
	if current_mission_intent.is_actionable():
		var existing_handlers := _squad_context.reserve_objective(unit, current_mission_intent.objective_id)
		_squad_notes.append("Objective handler: first" if existing_handlers == 0 else "Objective already handled by %d ally: spread/support" % existing_handlers)
	print_rich("[color=medium_purple][AI Goal][/color] %s — %s: %s" % [unit.name, current_mission_intent.get_debug_label(), current_mission_intent.reason])

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
	if unit.mission_actor and unit.mission_actor.is_vip():
		await _execute_vip_turn()
		_is_executing = false
		return
	var has_moved := false
	current_mission_intent = _objective_manager.get_mission_intent(unit) if _objective_manager else MissionIntentData.new()
	if current_mission_intent.kind == MissionIntentData.Kind.EXTRACT and _objective_manager.can_extract(unit):
		if await _try_mission_step(false) == MissionStepResult.EXTRACTED:
			_is_executing = false
			return
	while is_instance_valid(unit) and unit.stats.current_ap > 0 \
		and turn_manager.battle_result == TurnManager.BattleResult.ONGOING \
		and _should_control_unit():
		current_mission_intent = _objective_manager.get_mission_intent(unit) if _objective_manager else MissionIntentData.new()
		var mission_step := await _try_mission_step(has_moved)
		if mission_step == MissionStepResult.EXTRACTED:
			_is_executing = false
			return
		if mission_step == MissionStepResult.MOVED:
			has_moved = true
			continue
		if mission_step == MissionStepResult.INTERACTED:
			continue
		var attack_target = _find_attack_target()
		if attack_target and battle_controller.try_attack(unit, attack_target):
			_squad_context.reserve_target(unit, attack_target)
			if not _pending_target_note.is_empty(): _squad_notes.append(_pending_target_note)
			_record_ai_decision("Attack", attack_target.name, "Legal shot; target score balances vulnerability with allied focus.", "Move, Defend")
			await get_tree().create_timer(0.25).timeout
			continue
		var movement_target = _find_nearest_hostile()
		if not has_moved and movement_target and await _move_toward(movement_target):
			has_moved = true
			_record_ai_decision("Move", str(_last_move_destination), "No legal shot; approached the nearest hostile unit.", "Attack, Defend")
			continue
		if battle_controller.try_defend(unit):
			var reason := "No legal shot after moving." if has_moved else "No legal shot or reachable approach."
			_record_ai_decision("Defend", unit.name, reason, "Attack, Move")
		break

	if _should_control_unit():
		if turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_TURN:
			turn_manager.advance_automated_player(unit)
		else:
			turn_manager.end_current_turn()
	_is_executing = false

func _try_mission_step(has_moved: bool) -> MissionStepResult:
	if not current_mission_intent.is_actionable():
		return MissionStepResult.NONE
	if current_mission_intent.kind == MissionIntentData.Kind.RESCUE:
		var rescue_target := _objective_manager.find_mission_actor(current_mission_intent.target_ids)
		if rescue_target and _objective_manager.can_rescue(unit, rescue_target):
			_record_ai_decision("Rescue", rescue_target.name, "Rescue target is adjacent.", "Attack, Move, Defend")
			if _objective_manager.try_rescue(unit, rescue_target):
				return MissionStepResult.INTERACTED
		if not has_moved and rescue_target and await _move_toward(rescue_target):
			_record_ai_decision("Move", str(_last_move_destination), "Approached the rescue target.", "Attack, Defend")
			return MissionStepResult.MOVED
		return MissionStepResult.NONE
	if current_mission_intent.kind == MissionIntentData.Kind.PROTECT:
		var protected_actor := _objective_manager.find_mission_actor(current_mission_intent.target_ids)
		if not has_moved and protected_actor and _grid_distance_to(protected_actor) > 3 and await _move_toward_range(protected_actor, 3):
			_record_ai_decision("Move", str(_last_move_destination), "Returned to the protected actor's escort radius.", "Attack, Defend")
			return MissionStepResult.MOVED
		return MissionStepResult.NONE
	if current_mission_intent.kind == MissionIntentData.Kind.SURVIVE:
		if not has_moved:
			var survival_position := _best_survival_position()
			if survival_position.x >= 0 and await _move_toward_cell(survival_position):
				_record_ai_decision("Move", str(_last_move_destination), "Improved cover and separation while the survival timer is active.", "Attack, Defend")
				return MissionStepResult.MOVED
		return MissionStepResult.NONE
	if current_mission_intent.kind == MissionIntentData.Kind.EXTRACT and _objective_manager.can_extract(unit):
		var carrier := _objective_manager.find_rescue_carrier(unit.faction)
		if carrier and carrier != unit:
			return MissionStepResult.NONE
		_record_ai_decision("Extract", current_mission_intent.zone_id, "Unit reached its mission extraction zone.", "Attack, Move, Defend")
		if _objective_manager.try_extract(unit):
			await get_tree().process_frame
			if turn_manager.battle_result == TurnManager.BattleResult.ONGOING and turn_manager.active_unit == null:
				turn_manager.end_current_turn()
			return MissionStepResult.EXTRACTED
	if has_moved or current_mission_intent.kind not in [MissionIntentData.Kind.REACH, MissionIntentData.Kind.EXTRACT]:
		return MissionStepResult.NONE
	if current_mission_intent.kind == MissionIntentData.Kind.EXTRACT:
		var rescue_carrier := _objective_manager.find_rescue_carrier(unit.faction)
		if rescue_carrier and rescue_carrier != unit:
			if _grid_distance_to(rescue_carrier) > 2 and await _move_toward_range(rescue_carrier, 2):
				_squad_notes.append("Mobile objective support: +30")
				_record_ai_decision("Support", rescue_carrier.name, "Escorted the teammate carrying the rescued VIP.", "Attack, Extract, Defend")
				return MissionStepResult.MOVED
			return MissionStepResult.NONE

	var destination := _nearest_reachable_zone_cell(current_mission_intent.zone_id)
	if destination.x < 0:
		return MissionStepResult.NONE
	if await _move_toward_cell(destination):
		_record_ai_decision("Move", str(_last_move_destination), current_mission_intent.reason, "Attack, Defend")
		if is_instance_valid(unit) and current_mission_intent.kind == MissionIntentData.Kind.EXTRACT and _objective_manager.can_extract(unit):
			_record_ai_decision("Extract", current_mission_intent.zone_id, "Unit reached its mission extraction zone.", "Attack, Defend")
			if _objective_manager.try_extract(unit):
				await get_tree().process_frame
				if turn_manager.battle_result == TurnManager.BattleResult.ONGOING and turn_manager.active_unit == null:
					turn_manager.end_current_turn()
				return MissionStepResult.EXTRACTED
		if current_mission_intent.kind == MissionIntentData.Kind.REACH:
			# Objective outcomes are deferred so movement signals finish cleanly.
			await get_tree().process_frame
		return MissionStepResult.MOVED
	return MissionStepResult.NONE

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
		return turn_manager.allied_units.has(unit)
	if turn_manager.current_phase == TurnManager.TurnPhase.ENEMY_TURN:
		return unit.faction == TacticalUnit.Faction.ENEMY and not battle_controller.debug_enemy_control
	return false

func _execute_vip_turn() -> void:
	if unit.mission_actor.vip_behavior == MissionActor.VIPBehavior.FOLLOW_ESCORT:
		var escorts := turn_manager.player_units.filter(func(candidate: TacticalUnit): return candidate.mission_actor == null or not candidate.mission_actor.is_vip())
		if not escorts.is_empty():
			await _move_toward(escorts[0])
	if unit.stats.current_ap > 0:
		battle_controller.try_defend(unit)
	if _should_control_unit():
		turn_manager.end_current_turn()

func _move_toward(target: TacticalUnit) -> bool:
	return await _move_toward_range(target, 1)

func _move_toward_range(target: TacticalUnit, desired_distance: int) -> bool:
	var start_cell = battle_controller.grid_manager.get_unit_grid(unit)
	var target_cell = battle_controller.grid_manager.get_unit_grid(target)
	var path = battle_controller.pathfinder.calculate_3d_path(start_cell, target_cell)
	if path.size() <= 1:
		return false

	# Leave the requested path distance between the mover and an occupied target.
	for step in mini(desired_distance, path.size() - 1):
		path.remove_at(path.size() - 1)
	var reachable = battle_controller.pathfinder.get_reachable_cells(start_cell, unit.stats.speed)
	var best_candidate := Vector3i(-1, -1, -1)
	var best_adjustment := 0.0
	var best_score := -INF
	for destination_index in range(1, path.size()):
		var candidate = battle_controller.world_to_grid(path[destination_index])
		var squad_adjustment := _squad_context.destination_adjustment(unit, candidate) if _squad_context else 0.0
		var score := float(destination_index) + squad_adjustment
		if squad_adjustment > -1000.0 and score > best_score and reachable.has(candidate) and battle_controller.grid_manager.can_unit_occupy_cell(unit, candidate):
			best_candidate = candidate
			best_adjustment = squad_adjustment
			best_score = score
	if best_candidate.x >= 0 and await battle_controller.try_move(unit, best_candidate):
		_last_move_destination = best_candidate
		_reserve_destination(best_candidate, best_adjustment)
		return true
	return false

func _grid_distance_to(target: TacticalUnit) -> int:
	var from := battle_controller.grid_manager.get_unit_grid(unit)
	var to := battle_controller.grid_manager.get_unit_grid(target)
	return absi(from.x - to.x) + absi(from.y - to.y) + absi(from.z - to.z)

func _move_toward_cell(target_cell: Vector3i) -> bool:
	var start_cell := battle_controller.grid_manager.get_unit_grid(unit)
	var path := battle_controller.pathfinder.calculate_3d_path(start_cell, target_cell)
	if path.size() <= 1: return false
	var reachable := battle_controller.pathfinder.get_reachable_cells(start_cell, unit.stats.speed)
	var best_candidate := Vector3i(-1, -1, -1)
	var best_adjustment := 0.0
	var best_score := -INF
	for index in range(1, path.size()):
		var candidate := battle_controller.world_to_grid(path[index])
		var squad_adjustment := _squad_context.destination_adjustment(unit, candidate) if _squad_context else 0.0
		var score := float(index) + squad_adjustment
		if squad_adjustment > -1000.0 and score > best_score and reachable.has(candidate) and battle_controller.grid_manager.can_unit_occupy_cell(unit, candidate):
			best_candidate = candidate
			best_adjustment = squad_adjustment
			best_score = score
	if best_candidate.x >= 0 and await battle_controller.try_move(unit, best_candidate):
		_last_move_destination = best_candidate
		_reserve_destination(best_candidate, best_adjustment)
		return true
	return false

func _nearest_reachable_zone_cell(zone_id: StringName) -> Vector3i:
	var grid := battle_controller.grid_manager
	var start := grid.get_unit_grid(unit)
	var best := Vector3i(-1, -1, -1)
	var best_cost := INF
	for cell in grid.map_data.get_objective_zone(zone_id):
		if cell != start and not grid.can_unit_occupy_cell(unit, cell):
			continue
		var path := battle_controller.pathfinder.calculate_3d_path(start, cell)
		if cell == start:
			return cell
		var squad_adjustment := _squad_context.destination_adjustment(unit, cell) if _squad_context else 0.0
		var cost := path.size() - squad_adjustment
		if not path.is_empty() and cost < best_cost:
			best_cost = cost
			best = cell
	return best

func _best_survival_position() -> Vector3i:
	var grid := battle_controller.grid_manager
	var start := grid.get_unit_grid(unit)
	var best := start
	var best_score := _survival_position_score(start, start)
	for candidate in battle_controller.pathfinder.get_reachable_cells(start, unit.stats.speed):
		if candidate != start and not grid.can_unit_occupy_cell(unit, candidate):
			continue
		var score := _survival_position_score(candidate, start)
		if score > best_score:
			best_score = score
			best = candidate
	return best if best != start else Vector3i(-1, -1, -1)

func _survival_position_score(candidate: Vector3i, start: Vector3i) -> float:
	var grid := battle_controller.grid_manager
	var score := -0.15 * start.distance_to(candidate)
	if _squad_context:
		score += _squad_context.destination_adjustment(unit, candidate)
	var nearest_hostile := INF
	for hostile in _get_hostile_units():
		if not is_instance_valid(hostile):
			continue
		var hostile_cell := grid.get_unit_grid(hostile)
		nearest_hostile = minf(nearest_hostile, candidate.distance_to(hostile_cell))
		match CombatRules.get_directional_cover(hostile_cell, candidate, grid):
			MapCellData.CoverType.LOW:
				score += 24.0
			MapCellData.CoverType.FULL:
				score += 36.0
	if nearest_hostile < INF:
		score += minf(nearest_hostile, 12.0) * 1.5
	var extraction := grid.map_data.get_objective_zone(&"extract")
	if not extraction.is_empty():
		var nearest_exit := INF
		for exit_cell in extraction:
			nearest_exit = minf(nearest_exit, candidate.distance_to(exit_cell))
		score -= nearest_exit * 0.2
	return score

func _find_attack_target() -> TacticalUnit:
	var best_target: TacticalUnit
	var best_score := -INF
	_pending_target_note = ""
	for candidate in _get_hostile_units():
		if not is_instance_valid(candidate) or not candidate.stats or candidate.stats.is_defeated:
			continue
		if battle_controller.evaluate_attack(unit, candidate).is_legal:
			var focus_adjustment := _squad_context.target_adjustment(unit, candidate) if _squad_context else 0.0
			var score := float(candidate.stats.max_hp - candidate.stats.current_hp) + focus_adjustment
			if candidate.stats.current_hp <= 25: score += 20.0
			if score > best_score:
				best_target = candidate
				best_score = score
				_pending_target_note = "Target focus: %+.0f (%d allies engaged)" % [focus_adjustment, int(-focus_adjustment / 15.0)]
	return best_target

func _reserve_destination(cell: Vector3i, adjustment: float) -> void:
	if not _squad_context:
		return
	_squad_context.reserve_destination(unit, cell)
	if adjustment < 0.0:
		_squad_notes.append("Nearby destination reservation: %+.0f" % adjustment)
	else:
		_squad_notes.append("Destination reserved for later allies")

func _record_ai_decision(action: String, subject: String, reason: String, alternatives: String) -> void:
	var notes := "None" if _squad_notes.is_empty() else "; ".join(_squad_notes)
	battle_controller.record_ai_decision(unit, action, subject, reason, alternatives, current_mission_intent.get_debug_label(), notes)

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
