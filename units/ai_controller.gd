extends Node
class_name AIController

@export var unit: TacticalUnit
@export var turn_manager: TurnManager
@export var battle_controller: BattleController

func _ready() -> void:
	if not _validate_dependencies():
		return
		
	# Decoupled Signal Listener (Observer Pattern)
	turn_manager.active_unit_changed.connect(_on_active_unit_changed)


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
	# Guard Clause: Only trigger if THIS unit was activated during ENEMY_TURN
	if new_active_unit != unit:
		return
		
	if turn_manager.current_phase != TurnManager.TurnPhase.ENEMY_TURN:
		return

	print_rich("[color=magenta][AI][/color] Activated enemy unit: [b]%s[/b]" % unit.name)
	_execute_turn()


func _execute_turn() -> void:
	# Short delay to allow UI transitions and camera movement to complete
	await get_tree().create_timer(0.6).timeout
	
	# Guard Clause: Array bounds check before accessing .front()
	if turn_manager.player_units.is_empty():
		print_rich("[color=yellow][AI][/color] No valid player targets remaining. Ending turn.")
		turn_manager.end_current_turn()
		return
		
	var target_player: TacticalUnit = turn_manager.player_units.front()
	# Resolve grid coordinates through the BattleController service
	var start_grid: Vector3i = battle_controller.world_to_grid(unit.global_position)
	var end_grid: Vector3i = battle_controller.world_to_grid(target_player.global_position)
	
	print_rich("[color=magenta][AI][/color] Calculating path from %s to %s" % [start_grid, end_grid])
	
	# Delegate path calculation to BattleController's Pathfinder instance
	var world_path: PackedVector3Array = battle_controller.pathfinder.calculate_3d_path(start_grid, end_grid)
	print_rich("[color=magenta][AI][/color] Calculated %d path points." % world_path.size())
	
	# 1. PREVENT TILE OVERLAP: Remove target tile so enemy stops adjacent to player
	if world_path.size() > 1:
		var last_tile_grid = battle_controller.world_to_grid(world_path[world_path.size() - 1])
		if last_tile_grid == end_grid:
			world_path.remove_at(world_path.size() - 1)
			
	# 2. CAP MOVEMENT RANGE: Truncate path points by unit.move_range
	if world_path.size() > 1:
		var max_steps: int = min(unit.move_range, world_path.size() - 1)
		var truncated_path: PackedVector3Array = world_path.slice(0, max_steps + 1)
		
		# Record spatial transaction boundaries before executing movement
		var old_grid: Vector3i = battle_controller.world_to_grid(unit.global_position)
		
		unit.move_along_path(truncated_path)
		await unit.movement_finished
		
		# Commit spatial update to GridManager and Pathfinder graph
		var new_grid: Vector3i = battle_controller.world_to_grid(unit.global_position)
		battle_controller.grid_manager.update_unit_position(unit, old_grid, new_grid)
	else:
		print_rich("[color=yellow][AI][/color] Enemy is already adjacent to target or path is blocked.")
		
	turn_manager.end_current_turn()
