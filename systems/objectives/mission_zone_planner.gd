class_name MissionZonePlanner
extends RefCounted

static func populate_defaults(map_data: MapData) -> void:
	map_data.set_objective_zone(&"reach", _nearest_open_cells(map_data, Vector2i(floori(map_data.map_size.x / 2.0), floori(map_data.map_size.y / 2.0)), 4))
	map_data.set_objective_zone(&"extract", _nearest_open_cells(map_data, Vector2i(floori(map_data.map_size.x / 2.0), maxi(2, floori(map_data.map_size.y / 4.0))), 4))
	map_data.set_objective_zone(&"enemy_extract", _nearest_open_cells(map_data, Vector2i(2, floori(map_data.map_size.y / 2.0)), 4))

static func find_rescue_cell(map_data: MapData) -> Vector3i:
	var cells := _nearest_open_cells(map_data, Vector2i(floori(map_data.map_size.x / 2.0), floori(map_data.map_size.y / 2.0)), 1)
	return cells[0] if not cells.is_empty() else Vector3i(-1, -1, -1)

static func _nearest_open_cells(map_data: MapData, center: Vector2i, count: int) -> Array[Vector3i]:
	var candidates: Array[Vector3i] = []
	for cell: MapCellData in map_data.cells.values():
		if cell.grid_position.y == 0 and cell.walkable and cell.can_stop:
			candidates.append(cell.grid_position)
	candidates.sort_custom(func(a: Vector3i, b: Vector3i):
		return Vector2i(a.x, a.z).distance_squared_to(center) < Vector2i(b.x, b.z).distance_squared_to(center)
	)
	return candidates.slice(0, mini(count, candidates.size()))
