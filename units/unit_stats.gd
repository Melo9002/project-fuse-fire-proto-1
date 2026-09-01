extends Node
class_name UnitStats

@export var max_ap: int = 2
@export var speed: int = 6

var current_ap: int = 2:
	set(value):
		current_ap = clampi(value, 0, max_ap)
		ap_changed.emit(current_ap, max_ap) # Pass both parameters matching the signal definition

signal ap_changed(current_ap: int, max_ap: int)
signal unit_exhausted()
signal status_changed

## Indicates if the unit is currently in a defensive stance (reduces incoming damage).
var is_defending: bool = false:
	set(value):
		if is_defending != value:
			is_defending = value
			status_changed.emit()

func reset_turn() -> void:
	current_ap = max_ap

func consume_ap(amount: int) -> bool:
	if current_ap >= amount:
		current_ap -= amount
		if current_ap == 0:
			unit_exhausted.emit()
		return true
	return false

func has_enough_ap(amount: int) -> bool:
	return current_ap >= amount

## Call this at the start of the unit's turn to reset turn-based status modifiers
func reset_turn_statuses() -> void:
	is_defending = false
