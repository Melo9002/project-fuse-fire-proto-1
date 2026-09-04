extends Node3D
class_name BattleController

signal move_mode_toggled(is_active: bool)
signal attack_mode_toggled(is_active: bool)

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
var current_attack_zone: Array[Vector3i] = []

# Move Mode state authorization flag
var is_move_mode_active: bool = false:
	set(value):
		if is_move_mode_active != value:
			is_move_mode_active = value
			move_mode_toggled.emit(is_move_mode_active)
			if not is_move_mode_active:
				path_visualizer.clear_path()
				path_visualizer.clear_range_zone()

var is_attack_mode_active: bool = false:
	set(value):
		if is_attack_mode_active != value:
			is_attack_mode_active = value
			attack_mode_toggled.emit(is_attack_mode_active)
			if not is_attack_mode_active:
				path_visualizer.clear_range_zone()

func _ready() -> void:
	turn_manager.turn_phase_changed.connect(_on_turn_phase_changed)
	turn_manager.active_unit_changed.connect(_on_active_unit_changed)
	grid_manager.set_pathfinder(pathfinder)
	
	for unit_item in turn_manager.player_units + turn_manager.enemy_units:
		var start_grid = world_to_grid(unit_item.global_position)
		grid_manager.register_unit(unit_item, start_grid)
		unit_item.defeated.connect(_on_unit_defeated)
	
	if not mouse_raycaster or not map_floor or not path_visualizer:
		push_error("Missing critical node assignments on BattleController!")
		return
		
	mouse_raycaster.floor_clicked.connect(_on_floor_clicked)
	mouse_raycaster.unit_clicked.connect(_on_unit_clicked)
	_build_floor_graph()
	_perform_volume_scan()
	
	turn_manager.start_battle()

func toggle_move_mode() -> void:
	if turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_TURN:
		is_move_mode_active = not is_move_mode_active
		if is_move_mode_active:
			is_attack_mode_active = false
		if is_move_mode_active:
			update_unit_movement_zone()

func toggle_attack_mode() -> void:
	if turn_manager.current_phase != TurnManager.TurnPhase.PLAYER_TURN:
		return
	if not tactical_unit or not tactical_unit.stats or tactical_unit.stats.current_ap < UNIFORM_AP_COST:
		return

	if is_attack_mode_active:
		is_attack_mode_active = false
		return

	if is_move_mode_active:
		is_move_mode_active = false
	is_attack_mode_active = true
	update_attack_range()

func _process(_delta: float) -> void:
	if not turn_manager or turn_manager.current_phase != TurnManager.TurnPhase.PLAYER_TURN:
		return
		
	var floor_hit = mouse_raycaster.get_floor_raycast_result() if mouse_raycaster else {}
	if not floor_hit.is_empty() and grid_cursor:
		grid_cursor.update_hover_position(floor_hit.position)
		
	# Enterprise Guard: Hover paths rendered ONLY in Move Mode
	if not is_move_mode_active or tactical_unit.is_moving:
		path_visualizer.clear_path()
		return
		
	if not floor_hit.is_empty():
		var hover_grid = world_to_grid(floor_hit.position)
		if current_movement_zone.has(hover_grid):
			var path = _get_path_to_position(floor_hit.position)
			if path.size() > 1:
				path_visualizer.draw_path(path, Color(0.0, 0.5, 1.0, 0.4))
				return
				
	path_visualizer.clear_path()

func _on_unit_clicked(unit: TacticalUnit) -> void:
	if is_attack_mode_active and unit.faction == TacticalUnit.Faction.ENEMY:
		try_attack(tactical_unit, unit)
		return

	if turn_manager.select_player_unit(unit):
		is_move_mode_active = false
		is_attack_mode_active = false

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
		is_attack_mode_active = false

func _on_active_unit_changed(unit: TacticalUnit) -> void:
	tactical_unit = unit
	is_move_mode_active = false
	is_attack_mode_active = false

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

func update_attack_range() -> void:
	current_attack_zone.clear()
	if not tactical_unit or not tactical_unit.stats:
		path_visualizer.clear_range_zone()
		return

	var attacker_grid = world_to_grid(tactical_unit.global_position)
	for grid_pos in pathfinder.grid_to_id_map.keys():
		var point_id = pathfinder.grid_to_id_map[grid_pos]
		if pathfinder.astar.is_point_disabled(point_id):
			continue

		var distance = absi(attacker_grid.x - grid_pos.x) + absi(attacker_grid.y - grid_pos.y) + absi(attacker_grid.z - grid_pos.z)
		if distance == 0 or distance > tactical_unit.attack_range:
			continue

		var world_pos = grid_manager.grid_to_world(grid_pos)
		if has_line_of_sight_to_position(tactical_unit, world_pos):
			current_attack_zone.append(grid_pos)

	path_visualizer.draw_range_zone(current_attack_zone, Color(0.95, 0.2, 0.2, 0.3))

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
			
func can_attack(attacker: TacticalUnit, target: TacticalUnit) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	if not attacker.stats or not target.stats or attacker.stats.is_defeated or target.stats.is_defeated:
		return false
	if attacker.faction == target.faction:
		return false

	var attacker_grid = world_to_grid(attacker.global_position)
	var target_grid = world_to_grid(target.global_position)
	var grid_distance = absi(attacker_grid.x - target_grid.x) + absi(attacker_grid.y - target_grid.y) + absi(attacker_grid.z - target_grid.z)
	if grid_distance > attacker.attack_range:
		return false

	return has_line_of_sight(attacker, target)

func try_attack(attacker: TacticalUnit, target: TacticalUnit) -> bool:
	if not can_attack(attacker, target):
		return false

	var attack_cmd = AttackAction.new(attacker, target, UNIFORM_AP_COST)
	if not attack_cmd.execute():
		return false

	is_attack_mode_active = false
	is_move_mode_active = false
	return true

func has_line_of_sight(attacker: TacticalUnit, target: TacticalUnit) -> bool:
	return has_line_of_sight_to_position(attacker, target.global_position)

func has_line_of_sight_to_position(attacker: TacticalUnit, destination: Vector3) -> bool:
	var origin = attacker.global_position + Vector3.UP * 0.6
	destination += Vector3.UP * 0.6
	var query = PhysicsRayQueryParameters3D.create(origin, destination)
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _on_unit_defeated(unit: TacticalUnit) -> void:
	if not is_instance_valid(unit):
		return

	grid_manager.unregister_unit_at(world_to_grid(unit.global_position))
	turn_manager.remove_unit(unit)
	if tactical_unit == unit:
		tactical_unit = null
	is_move_mode_active = false
	is_attack_mode_active = false
	unit.queue_free()
