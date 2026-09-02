class_name UnitStats
extends Node
@export var speed: int = 5
@export_group("Movement")

## Domain component managing a unit's lifecycle resources and action budgets.

signal hp_changed(current: int, max_hp: int)
signal sp_changed(current: int, max_sp: int)
signal ap_changed(current: int, max_ap: int)
signal status_changed

@export_group("Health")
@export var max_hp: int = 100:
	set(value):
		max_hp = max(1, value)
		current_hp = min(current_hp, max_hp)

var current_hp: int = 100:
	set(value):
		var clamped_val = clampi(value, 0, max_hp)
		if current_hp != clamped_val:
			current_hp = clamped_val
			hp_changed.emit(current_hp, max_hp)

@export_group("Supply Points (SP)")
@export var max_sp: int = 4:
	set(value):
		max_sp = max(1, value)
		current_sp = min(current_sp, max_sp)

var current_sp: int = 4:
	set(value):
		var clamped_val = clampi(value, 0, max_sp)
		if current_sp != clamped_val:
			current_sp = clamped_val
			sp_changed.emit(current_sp, max_sp)

@export_group("Action Points (AP)")
@export var max_ap: int = 2:
	set(value):
		max_ap = max(1, value)
		current_ap = min(current_ap, max_ap)

var current_ap: int = 2:
	set(value):
		var clamped_val = clampi(value, 0, max_ap)
		if current_ap != clamped_val:
			current_ap = clamped_val
			ap_changed.emit(current_ap, max_ap)

var is_defending: bool = false:
	set(value):
		if is_defending != value:
			is_defending = value
			status_changed.emit()

func _ready() -> void:
	current_hp = max_hp
	current_sp = max_sp
	current_ap = max_ap

# --- RESOURCE TRANSACTIONS ---

func has_enough_ap(amount: int) -> bool:
	return current_ap >= amount

func consume_ap(amount: int) -> void:
	current_ap -= amount

func reset_ap() -> void:
	current_ap = max_ap

func has_enough_sp(amount: int) -> bool:
	return current_sp >= amount

func consume_sp(amount: int) -> void:
	current_sp -= amount

func restore_sp_to_max() -> void:
	current_sp = max_sp

func take_damage(amount: int) -> void:
	var final_damage = amount
	if is_defending:
		final_damage = int(amount * 0.5)
		
	current_hp -= final_damage
	print_rich("[color=orange][UnitStats][/color] %s took %d damage (HP: %d/%d)" % [get_parent().name, final_damage, current_hp, max_hp])

func reset_turn_statuses() -> void:
	is_defending = false
	
func reset_turn() -> void:
	reset_ap()
	reset_turn_statuses()
