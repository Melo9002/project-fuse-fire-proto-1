class_name FlatMapGenerator
extends RefCounted

static func generate(width: int, depth: int, cell_size: float, map_seed: int, spawn_capacity: int = 5) -> MapData:
	var map_data := MapData.new()
	map_data.source_kind = "generated_flat"
	map_data.generation_seed = map_seed
	map_data.map_size = Vector2i(width, depth)
	var half_width := float(width) * cell_size * 0.5
	var half_depth := float(depth) * cell_size * 0.5
	for x in width:
		for z in depth:
			var cell_position := Vector3i(x, 0, z)
			var world_position := Vector3(
				float(x) * cell_size - half_width + cell_size * 0.5,
				0.0,
				float(z) * cell_size - half_depth + cell_size * 0.5
			)
			map_data.add_cell(MapCellData.new(cell_position, world_position))

	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var available_rows: Array[int] = []
	for z in range(1, depth - 1):
		available_rows.append(z)
	_shuffle(available_rows, rng)
	var player_rows := available_rows.slice(0, spawn_capacity)
	_shuffle(available_rows, rng)
	var enemy_rows := available_rows.slice(0, spawn_capacity)
	_shuffle(available_rows, rng)
	var ally_rows := available_rows.slice(0, spawn_capacity)
	var player_x := 1
	var enemy_x := width - 2
	if rng.randi_range(0, 1) == 1:
		player_x = width - 2
		enemy_x = 1
	for row in player_rows:
		map_data.add_spawn_cell(TacticalUnit.Faction.PLAYER, Vector3i(player_x, 0, row))
	for row in enemy_rows:
		map_data.add_spawn_cell(TacticalUnit.Faction.ENEMY, Vector3i(enemy_x, 0, row))
	var ally_x := player_x + (1 if player_x < enemy_x else -1)
	for row in ally_rows:
		map_data.add_spawn_cell(TacticalUnit.Faction.ALLY, Vector3i(ally_x, 0, row))
	map_data.rebuild_los_index()
	return map_data

static func generate_with_cover(width: int, depth: int, cell_size: float, map_seed: int, spawn_capacity: int = 5) -> MapData:
	var map_data := generate(width, depth, cell_size, map_seed, spawn_capacity)
	map_data.source_kind = "generated_cover"
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed ^ 0x5F3759DF
	var center_row := floori(float(depth) / 2.0)
	var anchors: Array[Vector3i] = []
	for x in range(5, width - 5):
		for z in range(2, depth - 2):
			anchors.append(Vector3i(x, 0, z))
	_shuffle_cells(anchors, rng)

	var desired_cover := clampi(floori(float(width * depth) / 10.0), 12, anchors.size())
	var placed := 0
	var templates := _formation_templates()
	var template_offset := rng.randi_range(0, templates.size() - 1)
	for anchor in anchors:
		if placed >= desired_cover:
			break
		var template: Array = templates[(template_offset + placed) % templates.size()]
		var rotation := rng.randi_range(0, 3)
		var formation := _rotated_formation(anchor, template, rotation)
		if not _can_place_formation(map_data, formation, width, depth, center_row):
			continue
		_apply_formation(map_data, formation)
		placed += formation.size()
	map_data.rebuild_los_index()
	return map_data

static func _formation_templates() -> Array[Array]:
	return [
		[[Vector2i(0, 0), MapCellData.CoverType.LOW], [Vector2i(1, 0), MapCellData.CoverType.FULL], [Vector2i(2, 0), MapCellData.CoverType.LOW]],
		[[Vector2i(0, 0), MapCellData.CoverType.FULL], [Vector2i(1, 0), MapCellData.CoverType.LOW], [Vector2i(0, 1), MapCellData.CoverType.LOW]],
		[[Vector2i(0, 0), MapCellData.CoverType.LOW], [Vector2i(1, 0), MapCellData.CoverType.LOW], [Vector2i(2, 0), MapCellData.CoverType.LOW]],
		[[Vector2i(0, 0), MapCellData.CoverType.LOW], [Vector2i(1, 0), MapCellData.CoverType.LOW], [Vector2i(2, 1), MapCellData.CoverType.FULL]],
	]

static func _rotated_formation(anchor: Vector3i, template: Array, rotation: int) -> Array:
	var formation: Array = []
	for member in template:
		var offset: Vector2i = member[0]
		for step in rotation:
			offset = Vector2i(-offset.y, offset.x)
		formation.append([anchor + Vector3i(offset.x, 0, offset.y), member[1]])
	return formation

static func _can_place_formation(map_data: MapData, formation: Array, width: int, depth: int, center_row: int) -> bool:
	for member in formation:
		var grid_position: Vector3i = member[0]
		var cover_type: MapCellData.CoverType = member[1]
		if grid_position.x < 5 or grid_position.x >= width - 5 or grid_position.z < 2 or grid_position.z >= depth - 2:
			return false
		if absi(grid_position.z - center_row) <= 1:
			return false
		var cell := map_data.get_cell(grid_position)
		if not cell or cell.cover_type != MapCellData.CoverType.NONE:
			return false
		if cover_type == MapCellData.CoverType.FULL and _has_adjacent_full_cover(map_data, grid_position):
			return false
	return true

static func _apply_formation(map_data: MapData, formation: Array) -> void:
	for member in formation:
		var cell := map_data.get_cell(member[0])
		cell.cover_type = member[1]
		cell.can_stop = false
		if cell.cover_type == MapCellData.CoverType.FULL:
			cell.cover_height = 2.0
			cell.blocks_line_of_sight = true
			cell.walkable = false
		else:
			cell.cover_height = 1.0
			cell.walkable = true
			cell.movement_cost = 2

static func _shuffle(values: Array[int], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := values[index]
		values[index] = values[swap_index]
		values[swap_index] = held

static func _shuffle_cells(values: Array[Vector3i], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := values[index]
		values[index] = values[swap_index]
		values[swap_index] = held

static func _has_adjacent_full_cover(map_data: MapData, grid_position: Vector3i) -> bool:
	for direction in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		var neighbor := map_data.get_cell(grid_position + direction)
		if neighbor and neighbor.cover_type == MapCellData.CoverType.FULL:
			return true
	return false
