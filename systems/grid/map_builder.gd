class_name MapBuilder
extends RefCounted

## Converts the authored scene into terrain data and a matching pathfinding graph.
static func build(grid: GridManager, pathfinder: Pathfinder) -> void:
	grid.map_data.clear()
	var grid_w = int(grid.map_floor.size.x / grid.cell_size)
	var grid_d = int(grid.map_floor.size.z / grid.cell_size)
	grid.map_data.source_kind = "authored"
	grid.map_data.map_size = Vector2i(grid_w, grid_d)
	for x in range(grid_w):
		for z in range(grid_d):
			var cell = Vector3i(x, 0, z)
			var world_position = grid.grid_to_world(cell)
			grid.map_data.add_cell(MapCellData.new(cell, world_position))
			pathfinder.add_walkable_cell(cell, world_position)

	for surface_node in grid.get_tree().get_nodes_in_group("elevated_surfaces"):
		var surface = surface_node as ElevatedSurface
		if surface:
			_add_elevated_surface(surface, grid, pathfinder)

	for path_node in grid.get_tree().get_nodes_in_group("elevation_paths"):
		var elevation_path = path_node as ElevationPath
		if elevation_path:
			_add_elevation_path(elevation_path, grid, pathfinder)

	for zone_node in grid.get_tree().get_nodes_in_group("spawn_zones"):
		var zone = zone_node as SpawnZone
		if zone:
			for spawn_cell in zone.get_spawn_cells(grid):
				grid.map_data.add_spawn_cell(zone.faction, spawn_cell)

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
				_apply_feature(cell_data, feature, pathfinder)
			elif cell_data:
				cell_data.walkable = false
				cell_data.can_stop = false
				pathfinder.disable_cell(grid_pos)

	# Authored metadata is deterministic even when CSG collision generation is late.
	for feature_node in grid.get_tree().get_nodes_in_group("terrain_features"):
		var feature = feature_node as TerrainFeature
		if not feature:
			continue
		for grid_pos in grid.map_data.cells:
			var cell_data = grid.map_data.get_cell(grid_pos)
			if feature.covers_position(cell_data.world_position):
				_apply_feature(cell_data, feature, pathfinder)

	for link_node in grid.get_tree().get_nodes_in_group("traversal_links"):
		var link = link_node as TraversalLink
		if not link:
			continue
		var link_data = link.to_data()
		grid.map_data.add_traversal_link(link_data)
		if not pathfinder.connect_cells(link_data.from_cell, link_data.to_cell, link_data.bidirectional):
			push_error("TraversalLink %s references missing cells" % link.name)

	grid.map_data.rebuild_los_index()

static func _add_elevated_surface(surface: ElevatedSurface, grid: GridManager, pathfinder: Pathfinder) -> void:
	for x in range(int(grid.map_floor.size.x / grid.cell_size)):
		for z in range(int(grid.map_floor.size.z / grid.cell_size)):
			var ground_cell := Vector3i(x, 0, z)
			if not surface.covers_position(grid.grid_to_world(ground_cell)):
				continue
			if surface.blocks_ground:
				var ground_data = grid.get_cell_data(ground_cell)
				if ground_data:
					ground_data.walkable = false
					ground_data.can_stop = false
					ground_data.cover_type = MapCellData.CoverType.FULL
					ground_data.cover_height = float(surface.elevation_level) * grid.elevation_step
					ground_data.blocks_line_of_sight = true
					pathfinder.disable_cell(ground_cell)
			var elevated_cell := Vector3i(x, surface.elevation_level, z)
			var world_position = grid.grid_to_world(elevated_cell)
			grid.map_data.add_cell(MapCellData.new(elevated_cell, world_position))
			pathfinder.add_walkable_cell(elevated_cell, world_position)

static func _add_elevation_path(elevation_path: ElevationPath, grid: GridManager, pathfinder: Pathfinder) -> void:
	for elevated_cell in elevation_path.get_cells():
		var ground_cell := Vector3i(elevated_cell.x, 0, elevated_cell.z)
		if elevation_path.blocks_ground:
			var ground_data = grid.get_cell_data(ground_cell)
			if ground_data:
				ground_data.walkable = false
				ground_data.can_stop = false
				ground_data.cover_type = MapCellData.CoverType.FULL
				ground_data.cover_height = float(elevated_cell.y) * grid.elevation_step
				ground_data.blocks_line_of_sight = true
				pathfinder.disable_cell(ground_cell)
		if grid.map_data.has_cell(elevated_cell):
			continue
		var world_position = grid.grid_to_world(elevated_cell)
		grid.map_data.add_cell(MapCellData.new(elevated_cell, world_position))
		pathfinder.add_walkable_cell(elevated_cell, world_position)

static func _apply_feature(cell: MapCellData, feature: TerrainFeature, pathfinder: Pathfinder) -> void:
	if feature.cover_type < cell.cover_type:
		return
	cell.cover_type = feature.cover_type
	cell.cover_height = feature.cover_height
	cell.blocks_line_of_sight = feature.blocks_line_of_sight
	cell.can_stop = false
	if feature.cover_type == MapCellData.CoverType.LOW:
		cell.walkable = true
		cell.movement_cost = feature.movement_cost
		pathfinder.configure_cell(cell.grid_position, true, false, feature.movement_cost)
	else:
		cell.walkable = false
		pathfinder.disable_cell(cell.grid_position)
