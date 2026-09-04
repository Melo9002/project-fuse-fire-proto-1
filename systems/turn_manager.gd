extends Node
class_name TurnManager

## Orchestrates turn lifecycle, phase transitions, and active unit queues.

enum TurnPhase { PLAYER_TURN, ENEMY_TURN, TRANSITION }

signal turn_phase_changed(new_phase: TurnPhase)
signal active_unit_changed(unit: TacticalUnit)
signal round_started(round_number: int)

@export_group("Battle Roster")
@export var player_units: Array[TacticalUnit] = []
@export var enemy_units: Array[TacticalUnit] = []

var current_phase: TurnPhase = TurnPhase.TRANSITION
var active_unit: TacticalUnit
var active_unit_index: int = 0
var current_round: int = 0

func start_battle() -> void:
	current_round = 1
	round_started.emit(current_round)
	_start_player_turn_phase()

func end_current_turn() -> void:
	# Guard: Refuse to end turn if the active unit is currently mid-animation/moving
	if active_unit and active_unit.is_moving:
		print_rich("[color=yellow][TurnManager][/color] Cannot end turn: Unit is still moving!")
		return
		
	print_rich("[color=yellow][TURN][/color] end_current_turn() called. Current Phase: ", current_phase)
	if current_phase == TurnPhase.PLAYER_TURN:
		_start_enemy_turn_phase()
	elif current_phase == TurnPhase.ENEMY_TURN:
		_advance_enemy_unit_queue()

func select_player_unit(unit: TacticalUnit) -> bool:
	if current_phase != TurnPhase.PLAYER_TURN:
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

# --- ENTERPRISE AP & PHASE AUTOMATION ---

## GDScript 2.0 Functional check: Returns true if ANY unit on the team has AP > 0.
func has_remaining_actions(team: Array[TacticalUnit]) -> bool:
	return team.any(func(unit: TacticalUnit) -> bool:
		return is_instance_valid(unit) and unit.stats != null and unit.stats.current_ap > 0
	)

## Call this after executing any command (Move, Attack, Defend, Resupply).
## Automatically advances the phase if no units on the active team have AP remaining.
func check_phase_completion() -> void:
	if current_phase == TurnPhase.PLAYER_TURN:
		if not has_remaining_actions(player_units):
			print_rich("[color=cyan][TurnManager][/color] All player units out of AP! Advancing to Enemy Phase...")
			_start_enemy_turn_phase()
	elif current_phase == TurnPhase.ENEMY_TURN:
		if not has_remaining_actions(enemy_units):
			print_rich("[color=cyan][TurnManager][/color] All enemy units out of AP! Advancing to next round...")
			_end_round()

# --- PHASE CONTROLLERS ---

func _start_player_turn_phase() -> void:
	current_phase = TurnPhase.PLAYER_TURN
	
	# Reset AP and status modifiers for all friendly units
	for unit in player_units:
		if is_instance_valid(unit) and unit.stats:
			unit.stats.reset_turn()
			
	if not player_units.is_empty():
		_set_active_unit(player_units[0])
		
	turn_phase_changed.emit(current_phase)

func _start_enemy_turn_phase() -> void:
	current_phase = TurnPhase.ENEMY_TURN
	
	# Reset AP and status modifiers for all enemy units
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
