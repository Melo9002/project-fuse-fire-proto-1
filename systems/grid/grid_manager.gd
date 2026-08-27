extends Node
class_name GridManager

@export var cell_size: float = 1.0
@export var map_floor: CSGBox3D

# Spatial Lookup Table: Key = Vector3i (grid_pos), Value = TacticalUnit
var occupancy_map: Dictionary = {}

# Reference to the Pathfinder service for automatic graph state synchronization
var pathfinder: Pathfinder = null

signal unit_registered(unit: TacticalUnit, grid_pos: Vector3i)
signal unit_unregistered(unit: TacticalUnit, grid_pos: Vector3i)

func set_pathfinder(pf: Pathfinder) -> void:
	pathfinder = pf

# --- OCCUPANCY REPOSITORY METHODS ---

func register_unit(unit: TacticalUnit, grid_pos: Vector3i) -> void:
	occupancy_map[grid_pos] = unit
	print_rich("[color=cyan][GridManager][/color] Registered unit [b]%s[/b] at %s | Faction: %s" % [unit.name, grid_pos, unit.faction])
	unit_registered.emit(unit, grid_pos)
	
	# Automatically disable A* node if it's an enemy blocking unit
	if pathfinder and unit.faction != TacticalUnit.Faction.PLAYER:
		pathfinder.disable_cell(grid_pos)
		print_rich("[color=magenta][Pathfinder][/color] Disabled enemy cell at %s" % grid_pos)

func unregister_unit_at(grid_pos: Vector3i) -> void:
	if occupancy_map.has(grid_pos):
		var unit = occupancy_map[grid_pos]
		occupancy_map.erase(grid_pos)
		if pathfinder:
			pathfinder.enable_cell(grid_pos)
		unit_unregistered.emit(unit, grid_pos)

func update_unit_position(unit: TacticalUnit, from_grid: Vector3i, to_grid: Vector3i) -> void:
	# 1. Clear old position and re-enable the old A* cell
	if occupancy_map.get(from_grid) == unit:
		occupancy_map.erase(from_grid)
		if pathfinder:
			pathfinder.enable_cell(from_grid)
			print_rich("[color=magenta][Pathfinder][/color] Re-enabled cleared cell at %s" % from_grid)
			
	# 2. Set new position and disable the new A* cell if it's an enemy blocking unit
	occupancy_map[to_grid] = unit
	if pathfinder and unit.faction != TacticalUnit.Faction.PLAYER:
		pathfinder.disable_cell(to_grid)
		print_rich("[color=magenta][Pathfinder][/color] Disabled new enemy cell at %s" % to_grid)

func is_cell_occupied(grid_pos: Vector3i) -> bool:
	return occupancy_map.has(grid_pos)

func get_unit_at(grid_pos: Vector3i) -> TacticalUnit:
	return occupancy_map.get(grid_pos, null)

# --- PASSTHROUGH & STOPPING RULES ---

## Determines if a unit can pass THROUGH a cell during movement planning
func can_unit_traverse_cell(moving_unit: TacticalUnit, grid_pos: Vector3i) -> bool:
	if not is_cell_occupied(grid_pos):
		return true
		
	var occupant = get_unit_at(grid_pos)
	if moving_unit.faction == TacticalUnit.Faction.PLAYER or moving_unit.faction == TacticalUnit.Faction.ALLY:
		return occupant.faction == TacticalUnit.Faction.PLAYER or occupant.faction == TacticalUnit.Faction.ALLY
		
	return occupant.faction == moving_unit.faction

## Determines if a unit can END its turn on a target cell
func can_unit_occupy_cell(_moving_unit: TacticalUnit, grid_pos: Vector3i) -> bool:
	return not is_cell_occupied(grid_pos)

# --- EXISTING COORDINATE CONVERSIONS ---

func grid_to_world(grid_pos: Vector3i) -> Vector3:
	if not map_floor:
		return Vector3.ZERO
	var half_width = map_floor.size.x / 2.0
	var half_depth = map_floor.size.z / 2.0
	var half_cell = cell_size / 2.0
	var floor_top_y = map_floor.global_position.y + (map_floor.size.y / 2.0)
	
	var world_x = (float(grid_pos.x) * cell_size) - half_width + half_cell
	var world_z = (float(grid_pos.z) * cell_size) - half_depth + half_cell
	return Vector3(world_x, floor_top_y, world_z)

func world_to_grid(pos: Vector3) -> Vector3i:
	if not map_floor:
		return Vector3i.ZERO
	var half_width = map_floor.size.x / 2.0
	var half_depth = map_floor.size.z / 2.0
	var x = floori((pos.x + half_width) / cell_size)
	var z = floori((pos.z + half_depth) / cell_size)
	return Vector3i(x, 0, z)

func get_tile_center(world_pos: Vector3) -> Vector3:
	return grid_to_world(world_to_grid(world_pos))
