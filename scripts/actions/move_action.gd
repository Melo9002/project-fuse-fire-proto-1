extends UnitAction
class_name MoveAction


## Command pattern object handling tactical unit grid traversal.
## Inherits from UnitAction (RefCounted) for automatic memory management.

var unit: TacticalUnit
var target_tile: Vector3i
var path: PackedVector3Array
var grid_manager: GridManager
var ap_cost: int

func _init(
	p_unit: TacticalUnit,
	p_target_tile: Vector3i,
	p_path: PackedVector3Array,
	p_grid_manager: GridManager,
	p_ap_cost: int = 1
) -> void:
	unit = p_unit
	target_tile = p_target_tile
	path = p_path
	grid_manager = p_grid_manager
	ap_cost = p_ap_cost

## Phase 1: Pre-Execution Validation (Guard Clauses)
func is_valid() -> bool:
	if not is_instance_valid(unit) or not unit.stats:
		return false
		
	if not unit.stats.has_enough_ap(ap_cost):
		return false
		
	if path.is_empty():
		return false
		
	return true

## Phase 2: Transaction Execution
func execute() -> bool:
	if not is_valid():
		return false
		
	# 1. State Mutation: Consume unit AP
	unit.stats.consume_ap(ap_cost)
	
	# 2. Spatial Index Update: Re-index occupied tile in GridManager
	if grid_manager:
		var current_grid = grid_manager.world_to_grid(unit.global_position)
		grid_manager.update_unit_position(unit, current_grid, target_tile)
		
	# 3. Interpolation Execution: Dispatch path traversal on the unit
	if unit.has_method("move_along_path"):
		unit.move_along_path(path)
		
	return true
