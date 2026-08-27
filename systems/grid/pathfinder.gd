extends Node
class_name Pathfinder

var astar := AStar3D.new()
var grid_to_id_map: Dictionary = {} # Maps Vector3i coordinates to unique integer IDs
var next_id: int = 0

# Registers a single tile coordinate to the internal A* database
func add_walkable_cell(grid_pos: Vector3i, world_pos: Vector3) -> void:
	if grid_to_id_map.has(grid_pos):
		return # Avoid duplicating existing nodes
		
	var id = next_id
	next_id += 1
	
	grid_to_id_map[grid_pos] = id
	astar.add_point(id, world_pos)
	
	# Automatically connect this fresh node to any existing adjacent neighbors
	var neighbors = [
		Vector3i(grid_pos.x + 1, grid_pos.y, grid_pos.z), # East
		Vector3i(grid_pos.x - 1, grid_pos.y, grid_pos.z), # West
		Vector3i(grid_pos.x, grid_pos.y, grid_pos.z + 1), # South
		Vector3i(grid_pos.x, grid_pos.y, grid_pos.z - 1)  # North
	]
	
	for neighbor in neighbors:
		if grid_to_id_map.has(neighbor):
			var neighbor_id = grid_to_id_map[neighbor]
			astar.connect_points(id, neighbor_id) # Draws bidirectional walkway

# The central routing calculation pipeline
func calculate_3d_path(start_grid: Vector3i, end_grid: Vector3i) -> PackedVector3Array:
	if not grid_to_id_map.has(start_grid) or not grid_to_id_map.has(end_grid):
		return PackedVector3Array() # Return an empty optimized array if out of bounds
		
	var start_id = grid_to_id_map[start_grid]
	var end_id = grid_to_id_map[end_grid]
	
	return astar.get_point_path(start_id, end_id)

# --- THE RESTORED FUNCTION ---
# Finds the unique ID mapped to a 3D coordinate and breaks its grid connections
func disable_cell(grid_pos: Vector3i) -> void:
	if grid_to_id_map.has(grid_pos):
		var target_id = grid_to_id_map[grid_pos]
		astar.set_point_disabled(target_id, true)
		print("Graph node disabled at grid position: ", grid_pos)


# BFS algorithm to map every reachable tile within 'max_steps'
func get_reachable_cells(start_grid: Vector3i, max_steps: int) -> Array[Vector3i]:
	var reachable: Array[Vector3i] = []
	
	# If the starting point doesn't exist or is disabled, return empty
	if not grid_to_id_map.has(start_grid):
		return reachable
	if astar.is_point_disabled(grid_to_id_map[start_grid]):
		return reachable
		
	var queue: Array = []
	# Store pairs of [grid_pos, current_distance]
	queue.append([start_grid, 0])
	
	var visited: Dictionary = {}
	visited[start_grid] = true
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var current_pos = current[0]
		var current_dist = current[1]
		
		# Add to our final reachable list (excluding the tile the unit is currently standing on)
		if current_pos != start_grid:
			reachable.append(current_pos)
			
		# If we've reached the range limit, don't look at this node's neighbors
		if current_dist >= max_steps:
			continue
			
		# Check the 4 cardinal directions
		var directions = [
			Vector3i(current_pos.x + 1, current_pos.y, current_pos.z), # East
			Vector3i(current_pos.x - 1, current_pos.y, current_pos.z), # West
			Vector3i(current_pos.x, current_pos.y, current_pos.z + 1), # South
			Vector3i(current_pos.x, current_pos.y, current_pos.z - 1)  # North
		]
		
		for neighbor in directions:
			if grid_to_id_map.has(neighbor) and not visited.has(neighbor):
				var neighbor_id = grid_to_id_map[neighbor]
				# CRITICAL: Only cross this tile if it isn't blocked by a wall!
				if not astar.is_point_disabled(neighbor_id):
					visited[neighbor] = true
					queue.append([neighbor, current_dist + 1])
					
	return reachable
