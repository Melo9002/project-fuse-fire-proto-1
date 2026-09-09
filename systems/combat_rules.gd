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

static func has_line_of_sight_to_position(attacker: TacticalUnit, destination: Vector3, grid: GridManager, world: World3D) -> bool:
	if _map_data_blocks_line(attacker.global_position, destination, grid):
		return false
	var origin = attacker.global_position + Vector3.UP * 0.6
	destination += Vector3.UP * 0.6
	var query = PhysicsRayQueryParameters3D.create(origin, destination)
	query.collision_mask = 1
	return world.direct_space_state.intersect_ray(query).is_empty()

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

static func _map_data_blocks_line(origin: Vector3, destination: Vector3, grid: GridManager) -> bool:
	var distance = origin.distance_to(destination)
	var sample_count = ceili(distance / (grid.cell_size * 0.25))
	var origin_cell = grid.world_to_grid(origin)
	var destination_cell = grid.world_to_grid(destination)
	for index in range(1, sample_count):
		var sample = origin.lerp(destination, float(index) / sample_count)
		var sample_cell = grid.world_to_grid(sample)
		if sample_cell == origin_cell or sample_cell == destination_cell:
			continue
		var data = grid.get_cell_data(sample_cell)
		if data and data.blocks_line_of_sight:
			return true
	return false
