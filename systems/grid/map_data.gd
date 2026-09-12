class_name MapData
extends RefCounted

var cells: Dictionary = {}
var columns: Dictionary = {}
var traversal_links: Array[TraversalLinkData] = []
var los_blocking_cells: Array[MapCellData] = []
var spawn_cells: Dictionary = {}

func add_cell(cell: MapCellData) -> void:
	cells[cell.grid_position] = cell
	var column_key := Vector2i(cell.grid_position.x, cell.grid_position.z)
	if not columns.has(column_key):
		columns[column_key] = []
	var column: Array = columns[column_key]
	for index in column.size():
		if column[index].grid_position == cell.grid_position:
			column[index] = cell
			return
	column.append(cell)

func get_cell(grid_position: Vector3i) -> MapCellData:
	return cells.get(grid_position, null)

func has_cell(grid_position: Vector3i) -> bool:
	return cells.has(grid_position)

func get_column_cells(x: int, z: int) -> Array[MapCellData]:
	var column: Array[MapCellData] = []
	column.assign(columns.get(Vector2i(x, z), []))
	return column

func add_traversal_link(link: TraversalLinkData) -> void:
	traversal_links.append(link)

func add_spawn_cell(faction: TacticalUnit.Faction, grid_position: Vector3i) -> void:
	if not spawn_cells.has(faction):
		spawn_cells[faction] = []
	var cells_for_faction: Array = spawn_cells[faction]
	cells_for_faction.append(grid_position)

func get_spawn_cells(faction: TacticalUnit.Faction) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	result.assign(spawn_cells.get(faction, []))
	return result

func get_total_spawn_count() -> int:
	var total := 0
	for faction_cells in spawn_cells.values():
		total += faction_cells.size()
	return total

func rebuild_los_index() -> void:
	los_blocking_cells.clear()
	for cell: MapCellData in cells.values():
		if cell.blocks_line_of_sight and cell.cover_height > 0.0:
			los_blocking_cells.append(cell)

func clear() -> void:
	cells.clear()
	columns.clear()
	traversal_links.clear()
	los_blocking_cells.clear()
	spawn_cells.clear()
