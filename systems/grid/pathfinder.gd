extends RefCounted
class_name Pathfinder

var astar := AStar3D.new()
var grid_to_id_map: Dictionary = {}
var movement_costs: Dictionary = {}
var stoppable_cells: Dictionary = {}
var next_id: int = 0

const DIRECTIONS: Array[Vector3i] = [
	Vector3i.RIGHT,
	Vector3i.LEFT,
	Vector3i.FORWARD,
	Vector3i.BACK,
]

func add_walkable_cell(grid_pos: Vector3i, world_pos: Vector3) -> void:
	if grid_to_id_map.has(grid_pos):
		return # Avoid duplicating existing nodes

	var id = next_id
	next_id += 1

	grid_to_id_map[grid_pos] = id
	astar.add_point(id, world_pos)
	movement_costs[grid_pos] = 1
	stoppable_cells[grid_pos] = true

	for direction in DIRECTIONS:
		var neighbor = grid_pos + direction
		if grid_to_id_map.has(neighbor):
			var neighbor_id = grid_to_id_map[neighbor]
			astar.connect_points(id, neighbor_id)

func configure_cell(grid_pos: Vector3i, traversable: bool, can_stop: bool, movement_cost: int = 1) -> void:
	if not grid_to_id_map.has(grid_pos):
		return
	var point_id = grid_to_id_map[grid_pos]
	astar.set_point_disabled(point_id, not traversable)
	astar.set_point_weight_scale(point_id, maxf(1.0, float(movement_cost)))
	movement_costs[grid_pos] = maxi(1, movement_cost)
	stoppable_cells[grid_pos] = can_stop

func calculate_3d_path(start_grid: Vector3i, end_grid: Vector3i) -> PackedVector3Array:
	if not grid_to_id_map.has(start_grid) or not grid_to_id_map.has(end_grid):
		return PackedVector3Array()
	if not stoppable_cells.get(end_grid, false):
		return PackedVector3Array()

	var start_id = grid_to_id_map[start_grid]
	var end_id = grid_to_id_map[end_grid]
	return astar.get_point_path(start_id, end_id)

func disable_cell(grid_pos: Vector3i) -> void:
	configure_cell(grid_pos, false, false)

## Dijkstra search respects terrain movement costs.
func get_reachable_cells(start_grid: Vector3i, movement_budget: int) -> Array[Vector3i]:
	var reachable: Array[Vector3i] = []
	if not grid_to_id_map.has(start_grid):
		return reachable
	if astar.is_point_disabled(grid_to_id_map[start_grid]):
		return reachable

	var frontier: Array = [[start_grid, 0]]
	var best_cost: Dictionary = {start_grid: 0}
	while not frontier.is_empty():
		frontier.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
		var current: Array = frontier.pop_front()
		var current_pos: Vector3i = current[0]
		var current_cost: int = current[1]
		if current_cost != best_cost[current_pos]:
			continue
		if current_pos != start_grid and stoppable_cells.get(current_pos, false):
			reachable.append(current_pos)

		for direction in DIRECTIONS:
			var neighbor = current_pos + direction
			if not grid_to_id_map.has(neighbor):
				continue
			if astar.is_point_disabled(grid_to_id_map[neighbor]):
				continue
			var new_cost = current_cost + int(movement_costs.get(neighbor, 1))
			if new_cost > movement_budget or (best_cost.has(neighbor) and best_cost[neighbor] <= new_cost):
				continue
			best_cost[neighbor] = new_cost
			frontier.append([neighbor, new_cost])

	return reachable
