class_name MapGraphBuilder
extends RefCounted

static func build(map_data: MapData, pathfinder: Pathfinder) -> void:
	pathfinder.clear()
	for cell: MapCellData in map_data.cells.values():
		pathfinder.add_walkable_cell(cell.grid_position, cell.world_position)
	for cell: MapCellData in map_data.cells.values():
		pathfinder.configure_cell(cell.grid_position, cell.walkable, cell.can_stop, cell.movement_cost)
	for link in map_data.traversal_links:
		if link:
			pathfinder.connect_cells(link.from_cell, link.to_cell, link.bidirectional)
