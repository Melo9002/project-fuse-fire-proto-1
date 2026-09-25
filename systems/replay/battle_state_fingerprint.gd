class_name BattleStateFingerprint
extends RefCounted

static func capture(turn_manager: TurnManager, grid: GridManager, objectives: ObjectiveManager) -> String:
	var active_name := "none"
	if is_instance_valid(turn_manager.active_unit):
		active_name = String(turn_manager.active_unit.name)
	var parts: Array[String] = [
		"round=%d" % turn_manager.current_round,
		"phase=%d" % turn_manager.current_phase,
		"active=%s" % active_name,
		"result=%d" % turn_manager.battle_result,
	]
	var units: Array[TacticalUnit] = []
	for value in grid.occupancy_map.values():
		var unit := value as TacticalUnit
		if is_instance_valid(unit) and not units.has(unit):
			units.append(unit)
	units.sort_custom(func(first: TacticalUnit, second: TacticalUnit): return String(first.name) < String(second.name))
	for unit in units:
		var cell := grid.get_unit_grid(unit)
		var carried_name := "none"
		if unit.is_carrying_unit():
			carried_name = String(unit.carried_unit.name)
		parts.append("unit=%s,%d,%d,%d,%d,%d,%d,%d,%s" % [
			unit.name, unit.faction, cell.x, cell.y, cell.z,
			unit.stats.current_hp if unit.stats else -1,
			unit.stats.current_ap if unit.stats else -1,
			int(unit.stats.is_defending) if unit.stats else 0,
			carried_name,
		])
	if objectives and objectives.mission:
		for state in objectives.get_objectives():
			parts.append("objective=%s,%d,%d" % [state.definition.objective_id, state.status, state.progress])
		parts.append("extraction=%d,%d,%d" % [objectives.extracted_vips, objectives.extracted_units, objectives.escaped_enemies])
	return "|".join(parts)
