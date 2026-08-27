extends Node3D
class_name BattleController

@export var cell_size: float = 1.0
@export var tactical_unit: TacticalUnit
@export var mouse_raycaster: MouseRaycaster
@export var grid_cursor: GridCursor
@export var path_visualizer: PathVisualizer 
@export var map_floor: CSGBox3D 
@export var grid_manager: GridManager
@export var turn_manager: TurnManager

var pathfinder := Pathfinder.new()
var current_movement_zone: Array[Vector3i] = []

func _ready() -> void:
	turn_manager.turn_phase_changed.connect(_on_turn_phase_changed)
	turn_manager.active_unit_changed.connect(_on_active_unit_changed)
	
	# Register pathfinder reference with GridManager for automatic graph sync
	grid_manager.set_pathfinder(pathfinder)
	
	for unit_item in turn_manager.player_units + turn_manager.enemy_units:
		var start_grid = world_to_grid(unit_item.global_position)
		grid_manager.register_unit(unit_item, start_grid)
	
	if not mouse_raycaster or not map_floor or not path_visualizer:
		push_error("Missing critical node assignments on BattleController!")
		return
		
	mouse_raycaster.floor_clicked.connect(_on_floor_clicked)
	
	# --- 1. BUILD THE FLOOR GRAPH ---
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
			
	print("3D A* Pathfinding graph fully populated on the floor surface!")

	# --- 2. PHYSICS VOLUME SCANNER (Godot 4 Shape Query) ---
	await get_tree().create_timer(0.05).timeout
	var space_state = get_world_3d().direct_space_state
	
	var cell_box := BoxShape3D.new()
	cell_box.size = Vector3(cell_size * 0.85, 1.8, cell_size * 0.85)
	
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = cell_box
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
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
			
	print("Level volume scan complete! Grid routing paths updated.")
	
	# --- 3. INITIALIZE THE TURN STATE ---
	turn_manager.start_battle()

func _process(_delta: float) -> void:
	if not turn_manager or turn_manager.current_phase != TurnManager.TurnPhase.PLAYER_TURN:
		path_visualizer.clear_path()
		return
		
	if not mouse_raycaster or not grid_cursor:
		return
		
	var hover_pos = mouse_raycaster.get_raycast_result()
	if hover_pos != Vector3.ZERO:
		grid_cursor.update_hover_position(hover_pos)
		
	if tactical_unit.is_moving:
		return
		
	if hover_pos != Vector3.ZERO:
		var hover_grid = world_to_grid(hover_pos)
		if current_movement_zone.has(hover_grid):
			var path = _get_path_to_position(hover_pos)
			if path.size() > 1:
				path_visualizer.draw_path(path, Color(0.0, 0.5, 1.0, 0.4))
				return
				
	path_visualizer.clear_path()

func _on_floor_clicked(raw_position: Vector3) -> void:
	if tactical_unit.is_moving or turn_manager.current_phase != TurnManager.TurnPhase.PLAYER_TURN:
		return
		
	# Guard: Ensure unit has enough AP to execute a standard move (Cost: 1 AP)
	const MOVE_AP_COST = 1
	if not tactical_unit.stats.has_enough_ap(MOVE_AP_COST):
		print_rich("[color=yellow][BattleController][/color] Unit has no AP remaining!")
		return
		
	var clicked_grid = world_to_grid(raw_position)
	if not current_movement_zone.has(clicked_grid):
		return
		
	var path = _get_path_to_position(raw_position)
	if path.size() > 1:
		# Deduct AP as part of the transaction commit
		tactical_unit.stats.consume_ap(MOVE_AP_COST)
		
		var old_grid = world_to_grid(tactical_unit.global_position)
		path_visualizer.draw_path(path, Color(0.6, 0.1, 0.8, 0.6))
		tactical_unit.move_along_path(path)
		path_visualizer.clear_range_zone()
		
		await tactical_unit.movement_finished
		
		var new_grid = world_to_grid(tactical_unit.global_position)
		grid_manager.update_unit_position(tactical_unit, old_grid, new_grid)
		
		# If the unit still has AP left, refresh its movement zone for a second action
		if tactical_unit.stats.current_ap > 0:
			update_unit_movement_zone()
		else:
			path_visualizer.clear_range_zone()
			# Optionally auto-end turn or wait for player to hit End Turn

func _on_turn_phase_changed(new_phase: TurnManager.TurnPhase) -> void:
	var is_player_control = (new_phase == TurnManager.TurnPhase.PLAYER_TURN)
	grid_cursor.visible = is_player_control
	if not is_player_control:
		path_visualizer.clear_path()
		path_visualizer.clear_range_zone()

func _on_active_unit_changed(unit: TacticalUnit) -> void:
	tactical_unit = unit
	if turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_TURN:
		update_unit_movement_zone()

# --- HELPER FUNCTIONS ---

func update_unit_movement_zone() -> void:
	if not tactical_unit or tactical_unit.is_moving:
		return
		
	# Retrieve movement capacity dynamically from the unit's stats domain model
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
	
	# Hostile nodes are already dynamically managed by GridManager, 
	# so we can directly query the pathfinder without manual override loops.
	return pathfinder.calculate_3d_path(start_grid, end_grid)

func world_to_grid(pos: Vector3) -> Vector3i:
	var half_width = map_floor.size.x / 2.0
	var half_depth = map_floor.size.z / 2.0
	var x = int(floor((pos.x + half_width) / cell_size))
	var z = int(floor((pos.z + half_depth) / cell_size))
	return Vector3i(x, 0, z)
