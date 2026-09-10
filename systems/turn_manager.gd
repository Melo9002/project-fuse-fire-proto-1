extends Node
class_name TurnManager

enum TurnPhase { PLAYER_TURN, ENEMY_TURN, TRANSITION }
enum BattleResult { ONGOING, VICTORY, DEFEAT }

signal turn_phase_changed(new_phase: TurnPhase)
signal active_unit_changed(unit: TacticalUnit)
signal round_started(round_number: int)
signal battle_ended(result: BattleResult)
signal player_actions_exhausted

@export_group("Battle Roster")
@export var player_units: Array[TacticalUnit] = []
@export var enemy_units: Array[TacticalUnit] = []

var current_phase: TurnPhase = TurnPhase.TRANSITION
var active_unit: TacticalUnit
var active_unit_index: int = 0
var current_round: int = 0
var battle_result: BattleResult = BattleResult.ONGOING

func start_battle() -> void:
	battle_result = BattleResult.ONGOING
	for unit in player_units:
		var callback = _on_player_ap_changed.bind(unit)
		if unit.stats and not unit.stats.ap_changed.is_connected(callback):
			unit.stats.ap_changed.connect(callback)
	current_round = 1
	round_started.emit(current_round)
	_start_player_turn_phase()

## Players end their phase manually; each AI ends its own activation.
func end_current_turn() -> void:
	if battle_result != BattleResult.ONGOING or is_any_unit_moving():
		print_rich("[color=yellow][TurnManager][/color] Cannot end turn: Unit is still moving!")
		return

	print_rich("[color=yellow][TURN][/color] end_current_turn() called. Current Phase: ", current_phase)
	if current_phase == TurnPhase.PLAYER_TURN:
		_start_enemy_turn_phase()
	elif current_phase == TurnPhase.ENEMY_TURN:
		_advance_enemy_unit_queue()

func select_player_unit(unit: TacticalUnit) -> bool:
	if current_phase != TurnPhase.PLAYER_TURN or battle_result != BattleResult.ONGOING or is_any_unit_moving():
		return false
	if not is_instance_valid(unit) or not player_units.has(unit):
		return false
	if not unit.stats or unit.stats.current_ap <= 0 or unit.is_moving:
		return false

	_set_active_unit(unit)
	return true

func can_unit_act(unit: TacticalUnit) -> bool:
	if battle_result != BattleResult.ONGOING or active_unit != unit or is_any_unit_moving():
		return false
	if not is_instance_valid(unit) or not unit.stats or unit.stats.is_defeated:
		return false
	if current_phase == TurnPhase.PLAYER_TURN:
		return player_units.has(unit)
	if current_phase == TurnPhase.ENEMY_TURN:
		return enemy_units.has(unit)
	return false

func remove_unit(unit: TacticalUnit) -> void:
	player_units.erase(unit)
	enemy_units.erase(unit)
	if active_unit == unit:
		active_unit = null
	_check_battle_result()

func is_any_unit_moving() -> bool:
	for unit in player_units + enemy_units:
		if is_instance_valid(unit) and unit.is_moving:
			return true
	return false

func _on_player_ap_changed(current: int, _maximum: int, unit: TacticalUnit) -> void:
	if current == 0:
		_advance_selection_if_needed.call_deferred(unit)

func _advance_selection_if_needed(exhausted_unit: TacticalUnit) -> void:
	if is_instance_valid(exhausted_unit) and exhausted_unit.is_moving:
		await exhausted_unit.movement_finished
	if current_phase != TurnPhase.PLAYER_TURN or active_unit != exhausted_unit:
		return
	if not is_instance_valid(exhausted_unit) or not exhausted_unit.stats or exhausted_unit.stats.current_ap > 0:
		return

	var start_index = player_units.find(exhausted_unit)
	for offset in range(1, player_units.size() + 1):
		var candidate = player_units[(start_index + offset) % player_units.size()]
		if is_instance_valid(candidate) and candidate.stats and not candidate.stats.is_defeated \
			and candidate.stats.current_ap > 0:
			_set_active_unit(candidate)
			return
	player_actions_exhausted.emit()

func _check_battle_result() -> void:
	if battle_result != BattleResult.ONGOING:
		return
	if enemy_units.is_empty():
		_finish_battle(BattleResult.VICTORY)
	elif player_units.is_empty():
		_finish_battle(BattleResult.DEFEAT)

func _finish_battle(result: BattleResult) -> void:
	battle_result = result
	current_phase = TurnPhase.TRANSITION
	active_unit = null
	turn_phase_changed.emit(current_phase)
	active_unit_changed.emit(null)
	battle_ended.emit(result)

func _start_player_turn_phase() -> void:
	current_phase = TurnPhase.PLAYER_TURN
	for unit in player_units:
		if is_instance_valid(unit) and unit.stats:
			unit.stats.reset_turn()

	if not player_units.is_empty():
		_set_active_unit(player_units[0])

	turn_phase_changed.emit(current_phase)

func _start_enemy_turn_phase() -> void:
	current_phase = TurnPhase.ENEMY_TURN
	for unit_item in enemy_units:
		if is_instance_valid(unit_item) and unit_item.stats:
			unit_item.stats.reset_turn()

	active_unit_index = 0
	if not enemy_units.is_empty():
		_set_active_unit(enemy_units[0])
		turn_phase_changed.emit(current_phase)
	else:
		_end_round()

func _advance_enemy_unit_queue() -> void:
	if battle_result != BattleResult.ONGOING:
		return
	active_unit_index += 1
	if active_unit_index < enemy_units.size():
		_set_active_unit(enemy_units[active_unit_index])
	else:
		_end_round()

func _end_round() -> void:
	current_round += 1
	round_started.emit(current_round)
	_start_player_turn_phase()

func _set_active_unit(unit: TacticalUnit) -> void:
	active_unit = unit
	active_unit_changed.emit(active_unit)
