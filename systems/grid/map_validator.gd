class_name MapValidator
extends RefCounted

static func validate(map_data: MapData, pathfinder: Pathfinder, required_spawn_counts: Dictionary = {}) -> MapValidationResult:
	var result := MapValidationResult.new()
	if not map_data:
		result.add_error("MAP_MISSING", "MapData is missing.")
		return result
	if map_data.cells.is_empty():
		result.add_error("NO_CELLS", "The battlefield contains no cells.")
		return result

	_validate_cells(map_data, pathfinder, result)
	_validate_los_index(map_data, result)
	_validate_links(map_data, pathfinder, result)
	_validate_spawns(map_data, pathfinder, required_spawn_counts, result)
	return result

static func _validate_cells(map_data: MapData, pathfinder: Pathfinder, result: MapValidationResult) -> void:
	for key in map_data.cells:
		var cell = map_data.cells[key] as MapCellData
		if not cell:
			result.add_error("NULL_CELL", "A map entry has no MapCellData.")
			continue
		if key != cell.grid_position:
			result.add_error("CELL_KEY_MISMATCH", "Dictionary key %s does not match the cell coordinate." % key, cell.grid_position, true)
		if not is_finite(cell.world_position.x) or not is_finite(cell.world_position.y) or not is_finite(cell.world_position.z):
			result.add_error("INVALID_WORLD_POSITION", "World position contains a non-finite value.", cell.grid_position, true)
		if not is_finite(cell.elevation):
			result.add_error("INVALID_ELEVATION", "Elevation is not finite.", cell.grid_position, true)
		if cell.movement_cost < 1:
			result.add_error("INVALID_MOVEMENT_COST", "Movement cost must be at least 1.", cell.grid_position, true)
		if cell.cover_height < 0.0:
			result.add_error("INVALID_COVER_HEIGHT", "Cover height cannot be negative.", cell.grid_position, true)
		if cell.can_stop and not cell.walkable:
			result.add_error("INVALID_STOP_CELL", "A stoppable cell must also be walkable.", cell.grid_position, true)
		if cell.cover_type == MapCellData.CoverType.LOW and (not cell.walkable or cell.can_stop or cell.cover_height <= 0.0):
			result.add_error("INVALID_LOW_COVER", "Low cover must be traversable, non-stoppable, and have positive height.", cell.grid_position, true)
		if cell.cover_type == MapCellData.CoverType.FULL and (cell.walkable or cell.can_stop or cell.cover_height <= 0.0):
			result.add_error("INVALID_FULL_COVER", "Full cover must block walking and have positive height.", cell.grid_position, true)
		if cell.blocks_line_of_sight and cell.cover_height <= 0.0:
			result.add_error("INVALID_LOS_BLOCKER", "LOS-blocking terrain must have positive height.", cell.grid_position, true)
		if not pathfinder or not pathfinder.grid_to_id_map.has(cell.grid_position):
			result.add_error("PATH_NODE_MISSING", "Cell has no matching pathfinding node.", cell.grid_position, true)
		elif pathfinder.astar.is_point_disabled(pathfinder.grid_to_id_map[cell.grid_position]) == cell.walkable:
			result.add_error("PATH_STATE_MISMATCH", "Pathfinding availability disagrees with walkability.", cell.grid_position, true)

static func _validate_los_index(map_data: MapData, result: MapValidationResult) -> void:
	var indexed: Dictionary = {}
	for blocker in map_data.los_blocking_cells:
		if not blocker or not map_data.has_cell(blocker.grid_position):
			result.add_error("UNKNOWN_LOS_BLOCKER", "The LOS index references a missing cell.")
			continue
		indexed[blocker.grid_position] = true
		if not blocker.blocks_line_of_sight or blocker.cover_height <= 0.0:
			result.add_error("STALE_LOS_BLOCKER", "The LOS index contains terrain that cannot block shots.", blocker.grid_position, true)
	for cell: MapCellData in map_data.cells.values():
		if cell.blocks_line_of_sight and cell.cover_height > 0.0 and not indexed.has(cell.grid_position):
			result.add_error("LOS_BLOCKER_NOT_INDEXED", "LOS-blocking terrain is absent from the LOS index.", cell.grid_position, true)

static func _validate_links(map_data: MapData, pathfinder: Pathfinder, result: MapValidationResult) -> void:
	for link in map_data.traversal_links:
		if not link:
			result.add_error("NULL_TRAVERSAL_LINK", "Traversal-link data is missing.")
			continue
		if link.from_cell == link.to_cell:
			result.add_error("SELF_TRAVERSAL_LINK", "A traversal link cannot connect a cell to itself.", link.from_cell, true)
		for endpoint in [link.from_cell, link.to_cell]:
			var cell := map_data.get_cell(endpoint)
			if not cell:
				result.add_error("TRAVERSAL_ENDPOINT_MISSING", "Traversal link references a missing endpoint.", endpoint, true)
			elif not cell.walkable or not cell.can_stop:
				result.add_error("TRAVERSAL_ENDPOINT_INVALID", "Traversal endpoint must be a walkable stopping cell.", endpoint, true)
		if pathfinder and map_data.has_cell(link.from_cell) and map_data.has_cell(link.to_cell):
			var from_id: int = pathfinder.grid_to_id_map.get(link.from_cell, -1)
			var to_id: int = pathfinder.grid_to_id_map.get(link.to_cell, -1)
			if from_id < 0 or to_id < 0 or not pathfinder.astar.are_points_connected(from_id, to_id, link.bidirectional):
				result.add_error("TRAVERSAL_LINK_DISCONNECTED", "Traversal link is absent from the path graph.", link.from_cell, true)

static func _validate_spawns(map_data: MapData, pathfinder: Pathfinder, required_counts: Dictionary, result: MapValidationResult) -> void:
	var occupied_spawn_cells: Dictionary = {}
	for faction in map_data.spawn_cells:
		var faction_cells: Array[Vector3i] = map_data.get_spawn_cells(faction)
		for cell_position in faction_cells:
			if occupied_spawn_cells.has(cell_position):
				result.add_error("DUPLICATE_SPAWN", "Spawn cell is assigned to more than one position or faction.", cell_position, true)
			occupied_spawn_cells[cell_position] = faction
			var cell := map_data.get_cell(cell_position)
			if not cell:
				result.add_error("SPAWN_CELL_MISSING", "Spawn references a cell outside the battlefield.", cell_position, true)
			elif not cell.walkable or not cell.can_stop:
				result.add_error("SPAWN_CELL_INVALID", "Spawn must be a walkable stopping cell.", cell_position, true)

	for faction in required_counts:
		var required: int = required_counts[faction]
		var available := map_data.get_spawn_cells(faction).size()
		if available < required:
			result.add_error("INSUFFICIENT_SPAWNS", "Faction %s needs %d spawn cells but has %d." % [faction, required, available])

	var player_spawns := map_data.get_spawn_cells(TacticalUnit.Faction.PLAYER)
	var enemy_spawns := map_data.get_spawn_cells(TacticalUnit.Faction.ENEMY)
	if player_spawns.is_empty() or enemy_spawns.is_empty():
		result.add_error("OPPOSING_SPAWNS_MISSING", "Player and enemy spawn data are both required.")
		return
	if not pathfinder:
		result.add_error("PATHFINDER_MISSING", "Spawn connectivity cannot be checked without a pathfinder.")
		return
	var combat_factions := [TacticalUnit.Faction.PLAYER, TacticalUnit.Faction.ALLY, TacticalUnit.Faction.ENEMY]
	for first_index in combat_factions.size():
		var first_faction: TacticalUnit.Faction = combat_factions[first_index]
		for second_index in range(first_index + 1, combat_factions.size()):
			var second_faction: TacticalUnit.Faction = combat_factions[second_index]
			if not FactionRules.are_hostile(first_faction, second_faction):
				continue
			for first_cell in map_data.get_spawn_cells(first_faction):
				for second_cell in map_data.get_spawn_cells(second_faction):
					if map_data.has_cell(first_cell) and map_data.has_cell(second_cell) \
						and pathfinder.calculate_3d_path(first_cell, second_cell).is_empty():
						result.add_error("SPAWNS_DISCONNECTED", "Hostile spawn cells do not share a route: %s -> %s." % [first_cell, second_cell])
