extends Node
class_name TurnManager

enum TurnPhase { PLAYER_TURN, ENEMY_TURN, TRANSITION }
enum BattleResult { ONGOING, VICTORY, DEFEAT }

signal turn_phase_changed(new_phase: TurnPhase)
signal active_unit_changed(unit: TacticalUnit)
signal round_started(round_number: int)
signal battle_ended(result: BattleResult)

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
