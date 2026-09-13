class_name MatchSetup
extends Control

@export var player_count: SpinBox
@export var enemy_count: SpinBox
@export var ally_count: SpinBox
@export var start_button: Button
@export var generated_map_toggle: CheckButton
@export var seed_input: SpinBox
@export var map_size_option: OptionButton
@export var battle_scene: PackedScene

func _ready() -> void:
	var size_names := ["Small", "Medium", "Large"]
	for index in FlatMapGenerator.MAP_SIZES.size():
		var dimensions := FlatMapGenerator.MAP_SIZES[index]
		map_size_option.add_item("%s — %d × %d tiles" % [size_names[index], dimensions.x, dimensions.y])
	map_size_option.select(1)
	map_size_option.disabled = not generated_map_toggle.button_pressed
	start_button.pressed.connect(_start_battle)
	player_count.value_changed.connect(_update_summary)
	enemy_count.value_changed.connect(_update_summary)
	ally_count.value_changed.connect(_update_summary)
	generated_map_toggle.toggled.connect(_on_generation_toggled)
	seed_input.value_changed.connect(_update_summary)
	seed_input.editable = generated_map_toggle.button_pressed
	_update_summary(0.0)

func _update_summary(_value: float) -> void:
	var map_label := "GENERATED" if generated_map_toggle.button_pressed else "HANDMADE"
	start_button.text = "START %d + %d ALLIES VS %d — %s" % [int(player_count.value), int(ally_count.value), int(enemy_count.value), map_label]

func _on_generation_toggled(enabled: bool) -> void:
	map_size_option.disabled = not enabled
	seed_input.editable = enabled
	_update_summary(0.0)

func _start_battle() -> void:
	var battle = battle_scene.instantiate() as BattleLevel
	battle.configure(
		int(player_count.value),
		int(enemy_count.value),
		generated_map_toggle.button_pressed,
		int(seed_input.value),
		int(ally_count.value),
		FlatMapGenerator.MAP_SIZES[map_size_option.selected]
	)
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	queue_free()
