extends Control
class_name TurnHUDController

@export var turn_manager: TurnManager
@export var turn_label: Label
@export var end_turn_button: Button

func _ready() -> void:
	if not turn_manager or not turn_label or not end_turn_button:
		push_error("TurnHUDController: Missing UI dependencies!")
		return
	turn_manager.turn_phase_changed.connect(_on_turn_phase_changed)
	turn_manager.battle_ended.connect(_on_battle_ended)
	end_turn_button.pressed.connect(_on_end_turn_pressed)

func _on_turn_phase_changed(new_phase: TurnManager.TurnPhase) -> void:
	match new_phase:
		TurnManager.TurnPhase.PLAYER_TURN:
			turn_label.text = "PLAYER TURN"
			turn_label.modulate = Color.GREEN
			end_turn_button.disabled = false
		TurnManager.TurnPhase.ENEMY_TURN:
			turn_label.text = "ENEMY TURN"
			turn_label.modulate = Color.RED
			end_turn_button.disabled = true
		TurnManager.TurnPhase.TRANSITION:
			turn_label.text = "PHASE TRANSITION..."
			turn_label.modulate = Color.YELLOW
			end_turn_button.disabled = true

func _on_end_turn_pressed() -> void:
	print_rich("[color=cyan][UI][/color] End Turn button pressed!")
	if turn_manager:
		turn_manager.end_current_turn()

func _on_battle_ended(result: TurnManager.BattleResult) -> void:
	end_turn_button.disabled = true
	if result == TurnManager.BattleResult.VICTORY:
		turn_label.text = "VICTORY"
		turn_label.modulate = Color.GREEN
	else:
		turn_label.text = "DEFEAT"
		turn_label.modulate = Color.RED
