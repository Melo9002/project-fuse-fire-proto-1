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

static func evaluate_attack(attacker: TacticalUnit, target: TacticalUnit, grid: GridManager, world: World3D) -> AttackEvaluation:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return AttackEvaluation.new(false, 0, MapCellData.CoverType.NONE, "Invalid target")
	if not attacker.stats or not target.stats or attacker.stats.is_defeated or target.stats.is_defeated:
		return AttackEvaluation.new(false, 0, MapCellData.CoverType.NONE, "Unit defeated")
	if not FactionRules.are_hostile(attacker.faction, target.faction):
		return AttackEvaluation.new(false, 0, MapCellData.CoverType.NONE, "Not hostile")

	var attacker_grid = grid.world_to_grid(attacker.global_position)
	var target_grid = grid.world_to_grid(target.global_position)
	var grid_distance = absi(attacker_grid.x - target_grid.x) + absi(attacker_grid.y - target_grid.y) + absi(attacker_grid.z - target_grid.z)
	if grid_distance > attacker.attack_range:
		return AttackEvaluation.new(false, 0, MapCellData.CoverType.NONE, "Out of range")
	if not has_line_of_sight_to_position(attacker, target.global_position, grid, world):
		return AttackEvaluation.new(false, 0, MapCellData.CoverType.FULL, "Blocked")

	var cover = get_directional_cover(attacker_grid, target_grid, grid)
	var chance = 50 if cover == MapCellData.CoverType.LOW else 100
	return AttackEvaluation.new(true, chance, cover)

static func can_attack(attacker: TacticalUnit, target: TacticalUnit, grid: GridManager, world: World3D) -> bool:
	return evaluate_attack(attacker, target, grid, world).is_legal

static func has_line_of_sight_to_position(attacker: TacticalUnit, destination: Vector3, grid: GridManager, _world: World3D) -> bool:
	return get_blocking_cell(attacker.global_position, destination, grid) == null

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
	var cell = grid.world_to_grid(origin)
	var target = grid.world_to_grid(destination)
	var dx = absi(target.x - cell.x)
	var dz = absi(target.z - cell.z)
	var step_x = signi(target.x - cell.x)
	var step_z = signi(target.z - cell.z)
	var crossed_x := 0
	var crossed_z := 0
	# Compare boundary crossings exactly; touching a corner alone does not block.
	while cell != target:
		var next_x = (2 * crossed_x + 1) * dz
		var next_z = (2 * crossed_z + 1) * dx
		if next_x <= next_z:
			cell.x += step_x
			crossed_x += 1
		if next_z <= next_x:
			cell.z += step_z
			crossed_z += 1
		if cell == target:
			break
		var data = grid.get_cell_data(cell)
		if data and data.blocks_line_of_sight:
			return data
	return null
