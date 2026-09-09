class_name MapBuilder
extends RefCounted

## Builds the flat prototype terrain graph from the floor and environment colliders.
static func build(grid: GridManager, pathfinder: Pathfinder) -> void:
	var grid_w = int(grid.map_floor.size.x / grid.cell_size)
	var grid_d = int(grid.map_floor.size.z / grid.cell_size)
	for x in range(grid_w):
		for z in range(grid_d):
			var cell = Vector3i(x, 0, z)
			pathfinder.add_walkable_cell(cell, grid.grid_to_world(cell))

static func scan_obstacles(world: World3D, grid: GridManager, pathfinder: Pathfinder) -> void:
	var space_state = world.direct_space_state
	var cell_box := BoxShape3D.new()
	cell_box.size = Vector3(grid.cell_size * 0.85, 1.8, grid.cell_size * 0.85)

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = cell_box
	query.collide_with_bodies = true

	# Only environment bodies block terrain; floor and units use other layers.
	query.collision_mask = 1

	for grid_pos in pathfinder.grid_to_id_map.keys():
		var node_id = pathfinder.grid_to_id_map[grid_pos]
		var world_pos = pathfinder.astar.get_point_position(node_id)
		query.transform = Transform3D(Basis(), world_pos + Vector3(0, 1.0, 0))
		var hits = space_state.intersect_shape(query, 1)
		if not hits.is_empty():
			pathfinder.disable_cell(grid_pos)
