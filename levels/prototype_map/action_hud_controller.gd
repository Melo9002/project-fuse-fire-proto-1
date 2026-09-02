extends Control
class_name ActionHUDController

## View Mediator connecting HUD button events to BattleController commands.

@export var battle_controller: BattleController

@export_group("Action Buttons")
@export var move_button: Button
@export var attack_button: Button
@export var defend_button: Button
@export var resupply_button: Button

var _tracked_stats: UnitStats

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
	if resupply_button:
		resupply_button.pressed.connect(_on_resupply_pressed)
		
	# Subscribe to mediator state broadcasts
	battle_controller.move_mode_toggled.connect(_on_move_mode_toggled)
	
	var turn_mgr = battle_controller.turn_manager
	if turn_mgr:
		turn_mgr.turn_phase_changed.connect(_on_turn_phase_changed)
		turn_mgr.active_unit_changed.connect(_on_active_unit_changed)
		
		# Sync with currently selected unit if battle is already underway
		if turn_mgr.active_unit:
			_on_active_unit_changed(turn_mgr.active_unit)

# --- REACTIVE STAT OBSERVER ---

func _on_active_unit_changed(new_unit: TacticalUnit) -> void:
	# 1. Safely unbind from previous unit's stats to prevent dangling listeners
	if is_instance_valid(_tracked_stats):
		if _tracked_stats.ap_changed.is_connected(_on_resource_changed):
			_tracked_stats.ap_changed.disconnect(_on_resource_changed)
		if _tracked_stats.sp_changed.is_connected(_on_resource_changed):
			_tracked_stats.sp_changed.disconnect(_on_resource_changed)
			
	# 2. Bind to new unit's stats
	if is_instance_valid(new_unit) and new_unit.stats:
		_tracked_stats = new_unit.stats
		_tracked_stats.ap_changed.connect(_on_resource_changed)
		_tracked_stats.sp_changed.connect(_on_resource_changed)
	else:
		_tracked_stats = null
		
	_update_button_states()

func _on_resource_changed(_current: int, _max_val: int) -> void:
	_update_button_states()

# --- BUTTON EVENT HANDLERS ---

func _on_move_pressed() -> void:
	battle_controller.toggle_move_mode()

func _on_attack_pressed() -> void:
	var active_unit = battle_controller.tactical_unit
	if not active_unit or active_unit.is_moving:
		return
		
	var target_enemy = _find_placeholder_target()
	if target_enemy:
		var attack_cmd = AttackAction.new(active_unit, target_enemy, 1)
		if attack_cmd.execute():
			battle_controller.is_move_mode_active = false

func _on_defend_pressed() -> void:
	var active_unit = battle_controller.tactical_unit
	if not active_unit or active_unit.is_moving:
		return
		
	var defend_cmd = DefendAction.new(active_unit, 1)
	if defend_cmd.execute():
		battle_controller.is_move_mode_active = false

func _on_resupply_pressed() -> void:
	var active_unit = battle_controller.tactical_unit
	if not active_unit or active_unit.is_moving:
		return
		
	var resupply_cmd = ResupplyAction.new(active_unit, 1)
	if resupply_cmd.execute():
		battle_controller.is_move_mode_active = false

# --- RECTIFY UI STATE ON GAME EVENTS ---

func _on_move_mode_toggled(is_active: bool) -> void:
	if move_button:
		move_button.text = "Cancel Move" if is_active else "Move (1 AP)"

func _on_turn_phase_changed(new_phase: TurnManager.TurnPhase) -> void:
	visible = (new_phase == TurnManager.TurnPhase.PLAYER_TURN)
	_update_button_states()

func _update_button_states() -> void:
	var unit = battle_controller.tactical_unit if battle_controller else null
	var stats = unit.stats if (is_instance_valid(unit) and unit.stats) else null
	
	if not stats:
		_disable_all_buttons()
		return

	var has_ap = stats.current_ap >= 1
	var has_sp = stats.current_sp >= 1
	var needs_sp = stats.current_sp < stats.max_sp
	
	if move_button:
		move_button.disabled = not has_ap
	if attack_button:
		attack_button.disabled = not (has_ap and has_sp)
	if defend_button:
		defend_button.disabled = not has_ap
	if resupply_button:
		resupply_button.disabled = not (has_ap and needs_sp)

func _disable_all_buttons() -> void:
	if move_button: move_button.disabled = true
	if attack_button: attack_button.disabled = true
	if defend_button: defend_button.disabled = true
	if resupply_button: resupply_button.disabled = true

func _find_placeholder_target() -> TacticalUnit:
	if not battle_controller.turn_manager:
		return null
		
	var enemies = battle_controller.turn_manager.enemy_units
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.stats:
			if enemy.stats.current_hp > 0:
				return enemy
	return null
