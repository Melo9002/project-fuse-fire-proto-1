class_name UnitWorldBar
extends Control

@export_group("UI References")
@export var hp_bar: ProgressBar
@export var ap_label: Label

@export_group("3D Tracking Settings")
@export var world_offset: Vector3 = Vector3(0, 2.2, 0)

var _target_unit: Node3D
var _stats: UnitStats
var _active_camera: Camera3D

## Project the unit's world position into the UI layer each frame.
func setup(unit: Node3D, stats: UnitStats, faction: int = 0) -> void:
	_target_unit = unit
	_stats = stats

	_apply_faction_style(faction)

	if _stats:
		if not _stats.hp_changed.is_connected(_on_hp_changed):
			_stats.hp_changed.connect(_on_hp_changed)
		if not _stats.ap_changed.is_connected(_on_ap_changed):
			_stats.ap_changed.connect(_on_ap_changed)

		_on_hp_changed(_stats.current_hp, _stats.max_hp)
		_on_ap_changed(_stats.current_ap, _stats.max_ap)

func _process(_delta: float) -> void:
	if not is_instance_valid(_target_unit):
		queue_free()
		return

	if not is_instance_valid(_active_camera):
		_active_camera = get_viewport().get_camera_3d()
		if not _active_camera:
			return

	var target_world_pos = _target_unit.global_position + world_offset

	if _active_camera.is_position_behind(target_world_pos):
		hide()
	else:
		show()
		var screen_pos = _active_camera.unproject_position(target_world_pos)
		global_position = screen_pos - (size * 0.5)

func _apply_faction_style(faction_id: int) -> void:
	var team_color: Color
	match faction_id:
		0: # PLAYER
			team_color = Color("3498db") # Tactical Blue
		1: # ENEMY
			team_color = Color("e74c3c") # Enemy Red
		2: # ALLY
			team_color = Color("2ecc71") # Ally Green
		_:
			team_color = Color("f1c40f") # Neutral Yellow

	if hp_bar:
		var border_style = StyleBoxFlat.new()
		border_style.bg_color = Color(0, 0, 0, 0.6)
		border_style.border_color = team_color
		border_style.set_border_width_all(2)
		border_style.set_corner_radius_all(3)
		hp_bar.add_theme_stylebox_override("background", border_style)

func _on_hp_changed(current: int, max_val: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_val
		hp_bar.value = current

func _on_ap_changed(current: int, max_val: int) -> void:
	if ap_label:
		ap_label.text = "%d/%d AP" % [current, max_val]
