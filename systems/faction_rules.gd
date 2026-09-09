class_name FactionRules
extends RefCounted

## Defines relationships without involving the grid or input systems.
static func are_hostile(first: TacticalUnit.Faction, second: TacticalUnit.Faction) -> bool:
	var first_is_friendly = first == TacticalUnit.Faction.PLAYER or first == TacticalUnit.Faction.ALLY
	var second_is_friendly = second == TacticalUnit.Faction.PLAYER or second == TacticalUnit.Faction.ALLY
	return (first_is_friendly and second == TacticalUnit.Faction.ENEMY) \
		or (second_is_friendly and first == TacticalUnit.Faction.ENEMY)
