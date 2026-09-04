class_name AttackAction
extends UnitAction

var attacker: TacticalUnit
var target: TacticalUnit
var ap_cost: int

func _init(p_attacker: TacticalUnit, p_target: TacticalUnit, p_ap_cost: int = 1) -> void:
	attacker = p_attacker
	target = p_target
	ap_cost = p_ap_cost

func is_valid() -> bool:
	if not is_instance_valid(attacker) or not attacker.stats:
		return false
	if not is_instance_valid(target) or not target.stats:
		return false
	if attacker.stats.is_defeated or target.stats.is_defeated:
		return false
	if attacker.faction == target.faction:
		return false
		
	if not attacker.stats.has_enough_ap(ap_cost):
		return false
		
	return true

func execute() -> bool:
	if not is_valid():
		return false
		
	# 1. Deduct the action cost.
	attacker.stats.consume_ap(ap_cost)
	
	# 2. Execute combat transaction
	var base_damage = 25
	if target.stats.has_method("take_damage"):
		target.stats.take_damage(base_damage)
		
	print_rich("[color=red][AttackAction][/color] %s fired at %s!" % [attacker.name, target.name])
	return true
