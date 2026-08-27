extends Node
class_name ActionPointComponent

signal ap_changed(current_ap: int, max_ap: int)
signal ap_depleted

@export var max_ap: int = 2
var current_ap: int = 2

func reset_ap() -> void:
	current_ap = max_ap
	ap_changed.emit(current_ap, max_ap)

func can_afford(cost: int) -> bool:
	return current_ap >= cost

func consume_ap(cost: int) -> bool:
	if not can_afford(cost):
		return false
		
	current_ap -= cost
	ap_changed.emit(current_ap, max_ap)
	
	if current_ap <= 0:
		ap_depleted.emit()
		
	return true
