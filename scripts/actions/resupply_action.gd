class_name ResupplyAction
extends UnitAction

## Command pattern object handling tactical supply restoration.

var unit: TacticalUnit
var ap_cost: int

func _init(p_unit: TacticalUnit, p_ap_cost: int = 1) -> void:
	unit = p_unit
	ap_cost = p_ap_cost

func is_valid() -> bool:
	if not is_instance_valid(unit) or not unit.stats:
		return false
		
	# Unit must have enough AP and cannot resupply if already at max SP
	if not unit.stats.has_enough_ap(ap_cost):
		return false
		
	if unit.stats.current_sp >= unit.stats.max_sp:
		return false
		
	return true

func execute() -> bool:
	if not is_valid():
		return false
		
	# 1. Mutate AP State
	unit.stats.consume_ap(ap_cost)
	
	# 2. Mutate Supply State
	unit.stats.restore_sp_to_max()
	
	print_rich("[color=cyan][ResupplyAction][/color] %s resupplied to max SP (%d/%d)!" % [unit.name, unit.stats.current_sp, unit.stats.max_sp])
	return true
