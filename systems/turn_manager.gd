extends Node
class_name TurnManager

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
	print_rich("[color=yellow][TURN][/color] end_current_turn() called. Current Phase: ", current_phase)
	if current_phase == TurnPhase.PLAYER_TURN:
		_advance_player_unit_queue()
	elif current_phase == TurnPhase.ENEMY_TURN:
		_advance_enemy_unit_queue()

func _start_player_turn_phase() -> void:
	current_phase = TurnPhase.PLAYER_TURN
	turn_phase_changed.emit(current_phase)
	
	# Refresh AP for all player-controlled units at the start of the team round
	for unit in player_units:
		var ap_comp = unit.get_node_or_null("ActionPointComponent") as ActionPointComponent
		if ap_comp:
			ap_comp.reset_ap()
			
	active_unit_index = 0
	if not player_units.is_empty():
		_set_active_unit(player_units[0])

func _advance_player_unit_queue() -> void:
	active_unit_index += 1
	if active_unit_index < player_units.size():
		_set_active_unit(player_units[active_unit_index])
	else:
		_start_enemy_turn_phase()

func _start_enemy_turn_phase() -> void:
	current_phase = TurnPhase.ENEMY_TURN
	
	for unit_item in enemy_units:
		var ap_comp = unit_item.get_node_or_null("ActionPointComponent") as ActionPointComponent
		if ap_comp:
			ap_comp.reset_ap()
			
	active_unit_index = 0
	if not enemy_units.is_empty():
		_set_active_unit(enemy_units[0]) # 1. Assign active unit first
		turn_phase_changed.emit(current_phase) # 2. Emit phase update after
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
