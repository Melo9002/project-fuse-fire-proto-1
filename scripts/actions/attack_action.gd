class_name AttackAction
extends UnitAction

var attacker: TacticalUnit
var target: TacticalUnit
var ap_cost: int
var sp_cost: int

func _init(p_attacker: TacticalUnit, p_target: TacticalUnit, p_ap_cost: int = 1, p_sp_cost: int = 1) -> void:
	attacker = p_attacker
	target = p_target
	ap_cost = p_ap_cost
	sp_cost = p_sp_cost

func is_valid() -> bool:
	if not is_instance_valid(attacker) or not attacker.stats:
		return false
	if not is_instance_valid(target) or not target.stats:
		return false
		
	# Validate both resource constraints
	if not attacker.stats.has_enough_ap(ap_cost):
		return false
	if not attacker.stats.has_enough_sp(sp_cost):
		return false
		
	return true

func execute() -> bool:
	if not is_valid():
		return false
		
	# 1. Deduct resources
	attacker.stats.consume_ap(ap_cost)
	attacker.stats.consume_sp(sp_cost)
	
	# 2. Execute combat transaction
	var base_damage = 25
	if target.stats.has_method("take_damage"):
		target.stats.take_damage(base_damage)
		
	print_rich("[color=red][AttackAction][/color] %s fired at %s! (SP remaining: %d)" % [attacker.name, target.name, attacker.stats.current_sp])
	return true
