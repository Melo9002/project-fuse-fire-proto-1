class_name FlatMapGenerator
extends RefCounted

static func generate(width: int, depth: int, cell_size: float, seed: int, spawn_capacity: int = 5) -> MapData:
	var map_data := MapData.new()
	map_data.source_kind = "generated_flat"
	map_data.generation_seed = seed
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
	rng.seed = seed
	var available_rows: Array[int] = []
	for z in range(1, depth - 1):
		available_rows.append(z)
	_shuffle(available_rows, rng)
	var player_rows := available_rows.slice(0, spawn_capacity)
	_shuffle(available_rows, rng)
	var enemy_rows := available_rows.slice(0, spawn_capacity)
	var player_x := 1
	var enemy_x := width - 2
	if rng.randi_range(0, 1) == 1:
		player_x = width - 2
		enemy_x = 1
	for row in player_rows:
		map_data.add_spawn_cell(TacticalUnit.Faction.PLAYER, Vector3i(player_x, 0, row))
	for row in enemy_rows:
		map_data.add_spawn_cell(TacticalUnit.Faction.ENEMY, Vector3i(enemy_x, 0, row))
	map_data.rebuild_los_index()
	return map_data

static func generate_with_cover(width: int, depth: int, cell_size: float, seed: int, spawn_capacity: int = 5) -> MapData:
	var map_data := generate(width, depth, cell_size, seed, spawn_capacity)
	map_data.source_kind = "generated_cover"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ 0x5F3759DF
	var center_row := depth / 2
	var candidates: Array[Vector3i] = []
	for x in range(5, width - 5):
		for z in range(2, depth - 2):
			# A clear central route makes every spawn reachable without repairing maps afterward.
			if absi(z - center_row) <= 1:
				continue
			candidates.append(Vector3i(x, 0, z))
	_shuffle_cells(candidates, rng)

	var desired_cover := clampi((width * depth) / 10, 12, candidates.size())
	var placed := 0
	for grid_position in candidates:
		if placed >= desired_cover:
			break
		var cell := map_data.get_cell(grid_position)
		if not cell or cell.cover_type != MapCellData.CoverType.NONE:
			continue
		var make_full := rng.randf() < 0.35 and not _has_adjacent_full_cover(map_data, grid_position)
		if make_full:
			cell.cover_type = MapCellData.CoverType.FULL
			cell.cover_height = 2.0
			cell.blocks_line_of_sight = true
			cell.walkable = false
			cell.can_stop = false
		else:
			cell.cover_type = MapCellData.CoverType.LOW
			cell.cover_height = 1.0
			cell.walkable = true
			cell.can_stop = false
			cell.movement_cost = 2
		placed += 1
	map_data.rebuild_los_index()
	return map_data

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
