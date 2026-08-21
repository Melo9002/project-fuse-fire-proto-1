extends Node
class_name GridManager

@export var cell_size: float = 1.0
@export var map_floor: CSGBox3D

## Converts discrete grid coordinates to world-center 3D positions.
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

## Converts raw 3D world coordinates into discrete integer grid indices.
func world_to_grid(pos: Vector3) -> Vector3i:
	if not map_floor:
		return Vector3i.ZERO
	var half_width = map_floor.size.x / 2.0
	var half_depth = map_floor.size.z / 2.0
	var x = floori((pos.x + half_width) / cell_size)
	var z = floori((pos.z + half_depth) / cell_size)
	return Vector3i(x, 0, z)

## Gets the exact tile center in world space for any raw world coordinate.
func get_tile_center(world_pos: Vector3) -> Vector3:
	return grid_to_world(world_to_grid(world_pos))
