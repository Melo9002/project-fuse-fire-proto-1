extends Control
class_name ActionHUDController

## View Mediator connecting HUD button events to BattleController commands.

@export var battle_controller: BattleController

@export_group("Action Buttons")
@export var move_button: Button
@export var attack_button: Button
@export var defend_button: Button

func _ready() -> void:
	if not battle_controller:
		push_error("ActionHUDController: Missing BattleController reference!")
		return
		
	# Connect UI Button signals using Godot 4 Callables
	if move_button:
		move_button.pressed.connect(_on_move_pressed)
	if attack_button:
		attack_button.pressed.connect(_on_attack_pressed)
	if defend_button:
		defend_button.pressed.connect(_on_defend_pressed)
		
	# Subscribe to state broadcasts to update button interactability dynamically
	battle_controller.move_mode_toggled.connect(_on_move_mode_toggled)
	if battle_controller.turn_manager:
		battle_controller.turn_manager.turn_phase_changed.connect(_on_turn_phase_changed)

# --- BUTTON EVENT HANDLERS ---

func _on_move_pressed() -> void:
	# Toggle Movement Selection State on the mediator
	battle_controller.toggle_move_mode()

func _on_attack_pressed() -> void:
	# If an enemy unit is targeted/selected, construct and run AttackAction
	var active_unit = battle_controller.tactical_unit
	if not active_unit or active_unit.is_moving:
		return
		
	# Placeholder target resolution: For now, grabs the first registered enemy unit
	var target_enemy = _find_placeholder_target()
	if target_enemy:
		var attack_cmd = AttackAction.new(active_unit, target_enemy, 1)
		if attack_cmd.execute():
			battle_controller.is_move_mode_active = false
			_update_button_states()

func _on_defend_pressed() -> void:
	var active_unit = battle_controller.tactical_unit
	if not active_unit or active_unit.is_moving:
		return
		
	var defend_cmd = DefendAction.new(active_unit, 1)
	if defend_cmd.execute():
		battle_controller.is_move_mode_active = false
		_update_button_states()

# --- RECTIFY UI STATE ON GAME EVENTS ---

func _on_move_mode_toggled(is_active: bool) -> void:
	# Highlight Move button or update text visual state if active
	if move_button:
		move_button.text = "Cancel Move" if is_active else "Move (1 AP)"

func _on_turn_phase_changed(new_phase: TurnManager.TurnPhase) -> void:
	var is_player_turn = (new_phase == TurnManager.TurnPhase.PLAYER_TURN)
	visible = is_player_turn
	_update_button_states()

func _update_button_states() -> void:
	var unit = battle_controller.tactical_unit if battle_controller else null
	var has_ap = unit != null and unit.stats != null and unit.stats.current_ap >= 1
	
	if move_button:
		move_button.disabled = not has_ap
	if attack_button:
		attack_button.disabled = not has_ap
	if defend_button:
		defend_button.disabled = not has_ap

func _find_placeholder_target() -> TacticalUnit:
	var enemies = battle_controller.turn_manager.enemy_units
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.stats:
			# GDScript 2.0 safe property inspection: check if the property exists
			var hp = 1
			if "current_hp" in enemy.stats:
				hp = enemy.stats.current_hp
			elif "health" in enemy.stats:
				hp = enemy.stats.health
			elif "hp" in enemy.stats:
				hp = enemy.stats.hp
				
			if hp > 0:
				return enemy
	return null
