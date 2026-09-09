extends HBoxContainer
class_name APHUDController

@export var turn_manager: TurnManager
@export var ap_label: Label

var current_tracked_stats: UnitStats = null

func _ready() -> void:
	if turn_manager:
		turn_manager.active_unit_changed.connect(_on_active_unit_changed)

func _on_active_unit_changed(unit: TacticalUnit) -> void:
	if current_tracked_stats and current_tracked_stats.ap_changed.is_connected(_on_stats_ap_changed):
		current_tracked_stats.ap_changed.disconnect(_on_stats_ap_changed)

	var stats = unit.stats if is_instance_valid(unit) else null
	if not stats:
		_clear_display()
		current_tracked_stats = null
		return

	current_tracked_stats = stats
	current_tracked_stats.ap_changed.connect(_on_stats_ap_changed)

	_update_ap_display(current_tracked_stats.current_ap, current_tracked_stats.max_ap)

func _on_stats_ap_changed(current_ap: int, max_ap: int) -> void:
	_update_ap_display(current_ap, max_ap)

func _update_ap_display(current_ap: int, max_ap: int) -> void:
	if ap_label:
		ap_label.text = "AP: %d / %d" % [current_ap, max_ap]

func _clear_display() -> void:
	if ap_label:
		ap_label.text = "AP: --/--"
