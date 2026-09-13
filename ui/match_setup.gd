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
var vip_toggle: CheckButton
var vip_behavior: OptionButton
var objective_option: OptionButton

func _ready() -> void:
	_build_vip_setup()
	_build_objective_setup()
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

func _build_vip_setup() -> void:
	var box := VBoxContainer.new()
	box.name = "VIPSetup"
	vip_toggle = CheckButton.new()
	vip_toggle.text = "INCLUDE FRIENDLY VIP"
	vip_behavior = OptionButton.new()
	for label in ["Player Controlled", "Follow Escort", "Hold Position"]:
		vip_behavior.add_item(label)
	vip_behavior.disabled = true
	vip_toggle.toggled.connect(func(enabled: bool):
		vip_behavior.disabled = not enabled
		ally_count.max_value = 4.0 if enabled else 5.0
		ally_count.value = minf(ally_count.value, ally_count.max_value)
		_update_summary(0.0)
	)
	vip_behavior.item_selected.connect(func(_index: int):
		if vip_toggle.button_pressed and vip_behavior.selected != MissionActor.VIPBehavior.PLAYER_CONTROLLED and player_count.value < 2:
			player_count.value = 2
	)
	box.add_child(vip_toggle)
	box.add_child(vip_behavior)
	$CenterContainer/Panel/Margin/VBox.add_child(box)
	$CenterContainer/Panel/Margin/VBox.move_child(box, 3)

func _build_objective_setup() -> void:
	var box := VBoxContainer.new()
	box.name = "ObjectiveSetup"
	var label := Label.new()
	label.text = "MISSION OBJECTIVE"
	objective_option = OptionButton.new()
	objective_option.tooltip_text = "Choose the mission rules for this battle."
	for objective_name in MissionCatalog.get_preset_names():
		objective_option.add_item(objective_name)
	objective_option.item_selected.connect(_on_objective_selected)
	box.add_child(label)
	box.add_child(objective_option)
	$CenterContainer/Panel/Margin/VBox.add_child(box)
	$CenterContainer/Panel/Margin/VBox.move_child(box, 4)

func _on_objective_selected(index: int) -> void:
	var needs_vip := index == MissionObjectiveDefinition.Kind.PROTECT
	vip_toggle.disabled = needs_vip
	if needs_vip:
		vip_toggle.button_pressed = true
	_update_summary(0.0)

func _update_summary(_value: float) -> void:
	var map_label := "GENERATED" if generated_map_toggle.button_pressed else "HANDMADE"
	var vip_label := " + VIP" if vip_toggle and vip_toggle.button_pressed else ""
	var objective_label := MissionCatalog.get_preset_names()[objective_option.selected] if objective_option else "Eliminate"
	start_button.text = "START %d%s + %d ALLIES VS %d — %s — %s" % [int(player_count.value), vip_label, int(ally_count.value), int(enemy_count.value), map_label, objective_label.to_upper()]

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
		FlatMapGenerator.MAP_SIZES[map_size_option.selected],
		vip_toggle.button_pressed,
		vip_behavior.selected,
		MissionCatalog.create_mission(objective_option.selected, int(enemy_count.value), vip_toggle.button_pressed)
	)
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	queue_free()
