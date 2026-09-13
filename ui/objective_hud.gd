class_name ObjectiveHUD
extends VBoxContainer

@export var objective_manager: ObjectiveManager
@export var objective_label: Label
@export var end_mission_button: Button

func _ready() -> void:
	objective_manager.mission_loaded.connect(_on_changed)
	objective_manager.objective_progress_changed.connect(_on_changed)
	objective_manager.objective_completed.connect(_on_changed)
	objective_manager.objective_failed.connect(_on_changed)
	objective_manager.mission_report_changed.connect(_refresh)
	end_mission_button.pressed.connect(_on_end_mission)
	_refresh()

func _on_changed(_value) -> void:
	_refresh()

func _on_end_mission() -> void:
	objective_manager.end_mission_early()
	_refresh()

func _refresh() -> void:
	if not objective_manager or not objective_manager.mission:
		objective_label.text = "OBJECTIVE: NONE"
		end_mission_button.visible = false
		return
	var lines: Array[String] = []
	for state in objective_manager.get_objectives():
		var status: String = MissionObjectiveState.Status.keys()[state.status]
		lines.append("%s%s — %s  %d/%d" % ["" if state.definition.required else "OPTIONAL: ", state.definition.title.to_upper(), status, state.progress, state.definition.target_amount])
	objective_label.text = "OBJECTIVE: " + "\n".join(lines)
	end_mission_button.visible = objective_manager.can_end_mission_early()
