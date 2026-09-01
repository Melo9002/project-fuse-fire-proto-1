extends Node3D
class_name BattleController

signal move_mode_toggled(is_active: bool)

@export var cell_size: float = 1.0
@export var tactical_unit: TacticalUnit
@export var mouse_raycaster: MouseRaycaster
@export var grid_cursor: GridCursor
@export var path_visualizer: PathVisualizer 
@export var map_floor: CSGBox3D 
@export var grid_manager: GridManager
@export var turn_manager: TurnManager

const UNIFORM_AP_COST = 1

var pathfinder := Pathfinder.new()
var current_movement_zone: Array[Vector3i] = []

# Move Mode state authorization flag
var is_move_mode_active: bool = false:
	set(value):
		if is_move_mode_active != value:
			is_move_mode_active = value
			move_mode_toggled.emit(is_move_mode_active)
			if not is_move_mode_active:
				path_visualizer.clear_path()
				path_visualizer.clear_range_zone()

func _ready() -> void:
	turn_manager.turn_phase_changed.connect(_on_turn_phase_changed)
	turn_manager.active_unit_changed.connect(_on_active_unit_changed)
	grid_manager.set_pathfinder(pathfinder)
	
	for unit_item in turn_manager.player_units + turn_manager.enemy_units:
		var start_grid = world_to_grid(unit_item.global_position)
		grid_manager.register_unit(unit_item, start_grid)
	
	if not mouse_raycaster or not map_floor or not path_visualizer:
		push_error("Missing critical node assignments on BattleController!")
		return
		
	mouse_raycaster.floor_clicked.connect(_on_floor_clicked)
	_build_floor_graph()
	_perform_volume_scan()
	
	turn_manager.start_battle()

func toggle_move_mode() -> void:
	if turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_TURN:
		is_move_mode_active = not is_move_mode_active
		if is_move_mode_active:
			update_unit_movement_zone()

func _process(_delta: float) -> void:
	if not turn_manager or turn_manager.current_phase != TurnManager.TurnPhase.PLAYER_TURN:
		return
		
	var hover_pos = mouse_raycaster.get_raycast_result() if mouse_raycaster else Vector3.ZERO
	if hover_pos != Vector3.ZERO and grid_cursor:
		grid_cursor.update_hover_position(hover_pos)
		
	# Enterprise Guard: Hover paths rendered ONLY in Move Mode
	if not is_move_mode_active or tactical_unit.is_moving:
		path_visualizer.clear_path()
		return
		
	if hover_pos != Vector3.ZERO:
		var hover_grid = world_to_grid(hover_pos)
		if current_movement_zone.has(hover_grid):
			var path = _get_path_to_position(hover_pos)
			if path.size() > 1:
				path_visualizer.draw_path(path, Color(0.0, 0.5, 1.0, 0.4))
				return
				
	path_visualizer.clear_path()

# Inside BattleController.gd

func _on_floor_clicked(raw_position: Vector3) -> void:
	if not is_move_mode_active or tactical_unit.is_moving:
		return
		
	var clicked_grid = world_to_grid(raw_position)
	if not current_movement_zone.has(clicked_grid):
		return
		
	var path = _get_path_to_position(raw_position)
	if path.is_empty():
		return

	var action = MoveAction.new(tactical_unit, clicked_grid, path, grid_manager, 1)
	
	if action.execute():
		# Instantly deactivate move state so no further clicks execute
		is_move_mode_active = false
		
		# Await movement completion
		await tactical_unit.movement_finished
		
		# Clear range and path visualizers after arrival
		path_visualizer.clear_range_zone()
		path_visualizer.clear_path()
		
		# Do NOT set is_move_mode_active = true here!
		# The controller remains in neutral state until the player presses Move again.

func _on_turn_phase_changed(new_phase: TurnManager.TurnPhase) -> void:
	var is_player_control = (new_phase == TurnManager.TurnPhase.PLAYER_TURN)
	grid_cursor.visible = is_player_control
	if not is_player_control:
		is_move_mode_active = false

func _on_active_unit_changed(unit: TacticalUnit) -> void:
	tactical_unit = unit
	is_move_mode_active = false

func update_unit_movement_zone() -> void:
	if not tactical_unit or tactical_unit.is_moving:
		return
		
	var movement_budget = tactical_unit.stats.speed if tactical_unit.stats else 6
	var unit_grid = world_to_grid(tactical_unit.global_position)
	var raw_reachable = pathfinder.get_reachable_cells(unit_grid, movement_budget)
	
	current_movement_zone = raw_reachable.filter(
		func(cell: Vector3i) -> bool:
			if cell == unit_grid:
				return true
			return grid_manager.can_unit_occupy_cell(tactical_unit, cell)
	)
	
	path_visualizer.draw_range_zone(current_movement_zone, Color(0.9, 0.8, 0.1, 0.25))

func _get_path_to_position(target_world_pos: Vector3) -> PackedVector3Array:
	var start_grid = world_to_grid(tactical_unit.global_position)
	var end_grid = world_to_grid(target_world_pos)
	return pathfinder.calculate_3d_path(start_grid, end_grid)

func world_to_grid(pos: Vector3) -> Vector3i:
	var half_width = map_floor.size.x / 2.0
	var half_depth = map_floor.size.z / 2.0
	var x = int(floor((pos.x + half_width) / cell_size))
	var z = int(floor((pos.z + half_depth) / cell_size))
	return Vector3i(x, 0, z)

# Graph initialization helpers extracted for code cleanliness
func _build_floor_graph() -> void:
	var grid_w = int(map_floor.size.x / cell_size)
	var grid_d = int(map_floor.size.z / cell_size)
	var half_width = map_floor.size.x / 2.0
	var half_depth = map_floor.size.z / 2.0
	var half_cell = cell_size / 2.0
	var floor_top_y = map_floor.global_position.y + (map_floor.size.y / 2.0)
	
	for x in range(grid_w):
		for z in range(grid_d):
			var grid_pos = Vector3i(x, 0, z) 
			var world_x = (x * cell_size) - half_width + half_cell
			var world_z = (z * cell_size) - half_depth + half_cell
			var world_pos = Vector3(world_x, floor_top_y, world_z)
			pathfinder.add_walkable_cell(grid_pos, world_pos)

func _perform_volume_scan() -> void:
	await get_tree().create_timer(0.05).timeout
	var space_state = get_world_3d().direct_space_state
	var cell_box := BoxShape3D.new()
	cell_box.size = Vector3(cell_size * 0.85, 1.8, cell_size * 0.85)
	
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = cell_box
	query.collide_with_bodies = true
	
	var excluded_rids: Array[RID] = []
	if map_floor and map_floor.has_method("get_rid"):
		excluded_rids.append(map_floor.get_rid())
	for unit_item in turn_manager.player_units + turn_manager.enemy_units:
		if unit_item and unit_item.has_method("get_rid"):
			excluded_rids.append(unit_item.get_rid())
	query.exclude = excluded_rids
	
	for grid_pos in pathfinder.grid_to_id_map.keys():
		var node_id = pathfinder.grid_to_id_map[grid_pos]
		var world_pos = pathfinder.astar.get_point_position(node_id)
		query.transform = Transform3D(Basis(), world_pos + Vector3(0, 1.0, 0))
		var hits = space_state.intersect_shape(query, 1)
		if not hits.is_empty():
			pathfinder.disable_cell(grid_pos)
			
func dispatch_attack(target_enemy: TacticalUnit) -> void:
	var attack_cmd = AttackAction.new(tactical_unit, target_enemy, UNIFORM_AP_COST)
	if attack_cmd.execute():
		is_move_mode_active = false
