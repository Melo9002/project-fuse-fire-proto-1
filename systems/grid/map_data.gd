class_name MapData
extends RefCounted

var cells: Dictionary = {}

func add_cell(cell: MapCellData) -> void:
	cells[cell.grid_position] = cell

func get_cell(grid_position: Vector3i) -> MapCellData:
	return cells.get(grid_position, null)

func has_cell(grid_position: Vector3i) -> bool:
	return cells.has(grid_position)

func clear() -> void:
	cells.clear()

