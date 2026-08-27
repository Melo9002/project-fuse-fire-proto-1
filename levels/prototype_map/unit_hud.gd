extends Control
class_name UnitHUD

@export var turn_manager: TurnManager

# References to UI pips or labels representing the 2 AP budget
@export var ap_indicators: Array[Control] = [] 

var current_tracked_stats: UnitStats = null

func _ready() -> void:
	if turn_manager:
		turn_manager.active_unit_changed.connect(_on_active_unit_changed)

func _on_active_unit_changed(unit: TacticalUnit) -> void:
	# Unbind from previous unit's signals to avoid memory leaks / dangling references
	if current_tracked_stats and current_tracked_stats.ap_changed.is_connected(_update_ap_display):
		current_tracked_stats.ap_changed.disconnect(_update_ap_display)
		
	if not unit or not unit.stats:
		_hide_all_pips()
		current_tracked_stats = null
		return
		
	current_tracked_stats = unit.stats
	current_tracked_stats.ap_changed.connect(_update_ap_display)
	
	# Initial sync
	_update_ap_display(current_tracked_stats.current_ap)

func _update_ap_display(new_ap: int) -> void:
	for i in range(ap_indicators.size()):
		# If index is less than current AP, activate the pip; otherwise, dim it
		ap_indicators[i].visible = (i < new_ap)

func _hide_all_pips() -> void:
	for pip in ap_indicators:
		pip.visible = false
