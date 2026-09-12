class_name CombatRules
extends RefCounted

class AttackEvaluation:
	var is_legal: bool
	var hit_chance: int
	var cover_type: MapCellData.CoverType
	var reason: String

	func _init(
		legal: bool,
		chance: int = 0,
		cover: MapCellData.CoverType = MapCellData.CoverType.NONE,
		message: String = ""
	) -> void:
		is_legal = legal
		hit_chance = chance
		cover_type = cover
		reason = message

static func evaluate_attack(attacker: TacticalUnit, target: TacticalUnit, grid: GridManager, _world: World3D) -> AttackEvaluation:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return AttackEvaluation.new(false, 0, MapCellData.CoverType.NONE, "Invalid target")
	if not attacker.stats or not target.stats or attacker.stats.is_defeated or target.stats.is_defeated:
		return AttackEvaluation.new(false, 0, MapCellData.CoverType.NONE, "Unit defeated")
	if not FactionRules.are_hostile(attacker.faction, target.faction):
		return AttackEvaluation.new(false, 0, MapCellData.CoverType.NONE, "Not hostile")

	var attacker_grid = grid.get_unit_grid(attacker)
	var target_grid = grid.get_unit_grid(target)
	var grid_distance = absi(attacker_grid.x - target_grid.x) + absi(attacker_grid.y - target_grid.y) + absi(attacker_grid.z - target_grid.z)
	if grid_distance > attacker.attack_range:
		return AttackEvaluation.new(false, 0, MapCellData.CoverType.NONE, "Out of range")
	if get_blocking_cell_between_units(attacker, target, grid) != null:
		return AttackEvaluation.new(false, 0, MapCellData.CoverType.FULL, "Blocked")

	var cover = get_directional_cover(attacker_grid, target_grid, grid)
	var chance = 50 if cover == MapCellData.CoverType.LOW else 100
	return AttackEvaluation.new(true, chance, cover)

static func can_attack(attacker: TacticalUnit, target: TacticalUnit, grid: GridManager, world: World3D) -> bool:
	return evaluate_attack(attacker, target, grid, world).is_legal

static func has_line_of_sight_to_position(attacker: TacticalUnit, destination: Vector3, grid: GridManager, _world: World3D) -> bool:
	var target_cell = grid.world_to_grid(destination)
	var origin = grid.grid_to_world(grid.get_unit_grid(attacker)) + Vector3.UP * attacker.standing_height
	var target = grid.grid_to_world(target_cell) + Vector3.UP * attacker.standing_height
	return get_blocking_cell(origin, target, grid) == null

static func get_blocking_cell_between_units(attacker: TacticalUnit, target: TacticalUnit, grid: GridManager) -> MapCellData:
	return get_blocking_cell(get_shot_origin(attacker, grid), get_shot_destination(target, grid), grid)

static func get_shot_origin(attacker: TacticalUnit, grid: GridManager) -> Vector3:
	return grid.grid_to_world(grid.get_unit_grid(attacker)) + Vector3.UP * attacker.standing_height

static func get_shot_destination(target: TacticalUnit, grid: GridManager) -> Vector3:
	return grid.grid_to_world(grid.get_unit_grid(target)) + Vector3.UP * target.standing_height

static func get_directional_cover(attacker_cell: Vector3i, target_cell: Vector3i, grid: GridManager) -> MapCellData.CoverType:
	var delta = attacker_cell - target_cell
	var candidates: Array[Vector3i] = []
	if absi(delta.x) >= absi(delta.z) and delta.x != 0:
		candidates.append(target_cell + Vector3i(signi(delta.x), 0, 0))
	if absi(delta.z) >= absi(delta.x) and delta.z != 0:
		candidates.append(target_cell + Vector3i(0, 0, signi(delta.z)))

	var strongest = MapCellData.CoverType.NONE
	for cell in candidates:
		var data = grid.get_cell_data(cell)
		if data and data.cover_type > strongest:
			strongest = data.cover_type
	return strongest

static func get_blocking_cell(origin: Vector3, destination: Vector3, grid: GridManager) -> MapCellData:
	var origin_cell = grid.world_to_grid(origin)
	var target_cell = grid.world_to_grid(destination)
	for data: MapCellData in grid.map_data.los_blocking_cells:
		if data.grid_position == origin_cell or data.grid_position == target_cell:
			continue
		if _segment_enters_obstacle(origin, destination, data, grid.cell_size):
			return data
	return null

static func _segment_enters_obstacle(origin: Vector3, destination: Vector3, cell: MapCellData, cell_size: float) -> bool:
	var inset := 0.001
	var half_cell = cell_size * 0.5 - inset
	var minimum = Vector3(cell.world_position.x - half_cell, cell.world_position.y + inset, cell.world_position.z - half_cell)
	var maximum = Vector3(cell.world_position.x + half_cell, cell.world_position.y + cell.cover_height - inset, cell.world_position.z + half_cell)
	var direction = destination - origin
	var enter := 0.0
	var exit := 1.0
	for axis in 3:
		var start: float = origin[axis]
		var delta: float = direction[axis]
		if is_zero_approx(delta):
			if start <= minimum[axis] or start >= maximum[axis]:
				return false
			continue
		var first: float = (minimum[axis] - start) / delta
		var second: float = (maximum[axis] - start) / delta
		if first > second:
			var swap = first
			first = second
			second = swap
		enter = maxf(enter, first)
		exit = minf(exit, second)
		if enter >= exit:
			return false
	return exit > 0.0 and enter < 1.0
