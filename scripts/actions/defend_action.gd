class_name DefendAction
extends UnitAction

var unit: TacticalUnit
var ap_cost: int

func _init(p_unit: TacticalUnit, p_ap_cost: int = 1) -> void:
	unit = p_unit
	ap_cost = p_ap_cost

## Phase 1: Validation
func is_valid() -> bool:
	if not is_instance_valid(unit) or not unit.stats:
		return false
		
	if unit.stats.current_ap < ap_cost:
		return false
		
	return true

## Phase 2: Transaction Execution
func execute() -> bool:
	if not is_valid():
		return false
		
	# 1. Deduct all remaining AP or the standard cost to hunker down
	unit.stats.consume_ap(ap_cost)
	
	# 2. Apply defensive modifier state on UnitStats
	unit.stats.is_defending = true
	
	# 3. Fire domain signal for visual/audio feedback (e.g. status icon overlay)
	unit.stats.status_changed.emit()
	
	print_rich("[color=green][DefendAction][/color] %s is now in Defend stance." % unit.name)
	return true
