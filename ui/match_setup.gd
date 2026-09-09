class_name MatchSetup
extends Control

@export var player_count: SpinBox
@export var enemy_count: SpinBox
@export var start_button: Button
@export var battle_scene: PackedScene

func _ready() -> void:
	start_button.pressed.connect(_start_battle)
	player_count.value_changed.connect(_update_summary)
	enemy_count.value_changed.connect(_update_summary)
	_update_summary(0.0)

func _update_summary(_value: float) -> void:
	start_button.text = "START %d VS %d" % [int(player_count.value), int(enemy_count.value)]

func _start_battle() -> void:
	var battle = battle_scene.instantiate() as BattleLevel
	battle.configure(int(player_count.value), int(enemy_count.value))
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	queue_free()
