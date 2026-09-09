class_name MapBuilder
extends RefCounted

## Converts the authored scene into terrain data and a matching pathfinding graph.
static func build(grid: GridManager, pathfinder: Pathfinder) -> void:
	grid.map_data.clear()
	var grid_w = int(grid.map_floor.size.x / grid.cell_size)
	var grid_d = int(grid.map_floor.size.z / grid.cell_size)
	for x in range(grid_w):
		for z in range(grid_d):
			var cell = Vector3i(x, 0, z)
			var world_position = grid.grid_to_world(cell)
			grid.map_data.add_cell(MapCellData.new(cell, world_position))
			pathfinder.add_walkable_cell(cell, world_position)

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
			var cell_data = grid.map_data.get_cell(grid_pos)
			var feature = hits[0].collider as TerrainFeature
			if cell_data and feature:
				cell_data.cover_type = feature.cover_type
				cell_data.cover_height = feature.cover_height
				cell_data.blocks_line_of_sight = feature.blocks_line_of_sight
				if feature.cover_type == MapCellData.CoverType.LOW:
					cell_data.walkable = true
					cell_data.can_stop = false
					cell_data.movement_cost = feature.movement_cost
					pathfinder.configure_cell(grid_pos, true, false, feature.movement_cost)
				else:
					cell_data.walkable = false
					cell_data.can_stop = false
					pathfinder.disable_cell(grid_pos)
			elif cell_data:
				cell_data.walkable = false
				cell_data.can_stop = false
				pathfinder.disable_cell(grid_pos)
