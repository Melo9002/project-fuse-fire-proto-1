class_name CombatRules
extends RefCounted

## Checks faction, range, and walls without spending AP or dealing damage.
static func can_attack(attacker: TacticalUnit, target: TacticalUnit, grid: GridManager, world: World3D) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	if not attacker.stats or not target.stats or attacker.stats.is_defeated or target.stats.is_defeated:
		return false
	if not FactionRules.are_hostile(attacker.faction, target.faction):
		return false

	var attacker_grid = grid.world_to_grid(attacker.global_position)
	var target_grid = grid.world_to_grid(target.global_position)
	var grid_distance = absi(attacker_grid.x - target_grid.x) + absi(attacker_grid.y - target_grid.y) + absi(attacker_grid.z - target_grid.z)
	if grid_distance > attacker.attack_range:
		return false

	return has_line_of_sight_to_position(attacker, target.global_position, world)

static func has_line_of_sight_to_position(attacker: TacticalUnit, destination: Vector3, world: World3D) -> bool:
	var origin = attacker.global_position + Vector3.UP * 0.6
	destination += Vector3.UP * 0.6
	var query = PhysicsRayQueryParameters3D.create(origin, destination)
	# Units do not block shots in this prototype.
	query.collision_mask = 1
	return world.direct_space_state.intersect_ray(query).is_empty()
