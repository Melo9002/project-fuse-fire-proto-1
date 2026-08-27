extends HBoxContainer
class_name APHUDController

@export var turn_manager: TurnManager
@export var ap_pip_scene: PackedScene # Simple TextureRect representing 1 AP

func _ready() -> void:
	if turn_manager:
		turn_manager.active_unit_changed.connect(_on_active_unit_changed)

func _on_active_unit_changed(unit: TacticalUnit) -> void:
	var ap_comp = unit.get_node_or_null("ActionPointComponent") as ActionPointComponent
	if not ap_comp:
		_clear_pips()
		return
		
	# Re-bind AP signals for the new active unit
	if not ap_comp.ap_changed.is_connected(_update_ap_display):
		ap_comp.ap_changed.connect(_update_ap_display)
		
	_update_ap_display(ap_comp.current_ap, ap_comp.max_ap)

func _update_ap_display(current_ap: int, max_ap: int) -> void:
	_clear_pips()
	for i in range(max_ap):
		# Cast to Control (or ColorRect) instead of TextureRect
		var pip = ap_pip_scene.instantiate() as Control 
		if pip:
			pip.modulate = Color.WHITE if i < current_ap else Color(0.3, 0.3, 0.3, 0.5)
			add_child(pip)

func _clear_pips() -> void:
	for child in get_children():
		child.queue_free()
