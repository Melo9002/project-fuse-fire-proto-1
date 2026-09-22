class_name MatchSetup
extends Control

@export var player_count: SpinBox
@export var enemy_count: SpinBox
@export var ally_count: SpinBox
@export var start_button: Button
@export var generated_map_toggle: CheckButton
@export var auto_seed_toggle: CheckButton
@export var seed_input: SpinBox
@export var map_size_option: OptionButton
@export var battle_scene: PackedScene
var vip_toggle: CheckButton
var vip_behavior: OptionButton
var objective_option: OptionButton
var difficulty_option: OptionButton
var deployment_summary: Label
var _seed_rng := RandomNumberGenerator.new()

func _ready() -> void:
	_build_vip_setup()
	_build_objective_setup()
	_build_deployment_summary()
	_seed_rng.randomize()
	_prepare_new_seed()
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
	auto_seed_toggle.toggled.connect(_on_auto_seed_toggled)
	seed_input.value_changed.connect(_update_summary)
	_refresh_seed_controls()
	_update_summary(0.0)

func _build_vip_setup() -> void:
	var box := VBoxContainer.new()
	box.name = "VIPSetup"
	vip_toggle = CheckButton.new()
	vip_toggle.text = "INCLUDE ADDITIONAL FRIENDLY VIP"
	vip_toggle.tooltip_text = "Adds one mission actor outside the combatant counters."
	vip_behavior = OptionButton.new()
	vip_behavior.tooltip_text = "Choose who controls the additional VIP."
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
		_update_summary(0.0)
	)
	box.add_child(vip_toggle)
	box.add_child(vip_behavior)
	$CenterContainer/Panel/Margin/VBox.add_child(box)
	$CenterContainer/Panel/Margin/VBox.move_child(box, 3)

func _build_objective_setup() -> void:
	var box := HBoxContainer.new()
	box.name = "ObjectiveSetup"
	box.add_theme_constant_override("separation", 16)
	var objective_box := VBoxContainer.new()
	objective_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = "MISSION OBJECTIVE"
	objective_option = OptionButton.new()
	objective_option.tooltip_text = "Choose the mission rules for this battle."
	for objective_name in MissionCatalog.get_preset_names():
		objective_option.add_item(objective_name)
	objective_option.item_selected.connect(_on_objective_selected)
	objective_box.add_child(label)
	objective_box.add_child(objective_option)
	box.add_child(objective_box)
	var difficulty_box := VBoxContainer.new()
	difficulty_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var difficulty_label := Label.new()
	difficulty_label.text = "AI DIFFICULTY"
	difficulty_option = OptionButton.new()
	difficulty_option.tooltip_text = "Changes AI decisions for both teams; combat rules and AP stay the same."
	for tier in AIDifficultyPolicy.Tier.size():
		difficulty_option.add_item(AIDifficultyPolicy.get_label(tier))
	difficulty_option.select(AIDifficultyPolicy.Tier.NORMAL)
	difficulty_box.add_child(difficulty_label)
	difficulty_box.add_child(difficulty_option)
	box.add_child(difficulty_box)
	$CenterContainer/Panel/Margin/VBox.add_child(box)
	$CenterContainer/Panel/Margin/VBox.move_child(box, 4)

func _build_deployment_summary() -> void:
	deployment_summary = Label.new()
	deployment_summary.name = "DeploymentSummary"
	deployment_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deployment_summary.add_theme_color_override("font_color", Color(0.55, 0.86, 1.0))
	var box := $CenterContainer/Panel/Margin/VBox
	box.add_child(deployment_summary)
	box.move_child(deployment_summary, box.get_child_count() - 2)

func _on_objective_selected(index: int) -> void:
	var needs_vip := index == MissionObjectiveDefinition.Kind.PROTECT
	vip_toggle.disabled = needs_vip
	if needs_vip:
		vip_toggle.button_pressed = true
	_update_summary(0.0)

func _update_summary(_value: float) -> void:
	var map_label := "GENERATED" if generated_map_toggle.button_pressed else "HANDMADE"
	var objective_label := MissionCatalog.get_preset_names()[objective_option.selected] if objective_option else "Eliminate"
	var has_vip := vip_toggle != null and vip_toggle.button_pressed
	var player_vip := 1 if has_vip and vip_behavior.selected == MissionActor.VIPBehavior.PLAYER_CONTROLLED else 0
	var ai_vip := 1 if has_vip and vip_behavior.selected != MissionActor.VIPBehavior.PLAYER_CONTROLLED else 0
	var player_controlled := int(player_count.value) + player_vip
	var ai_controlled := int(ally_count.value) + ai_vip
	var friendly_total := player_controlled + ai_controlled
	if deployment_summary:
		deployment_summary.text = "DEPLOYMENT — Player-controlled: %d | AI allies: %d | Enemies: %d\nTotal friendly actors: %d%s" % [player_controlled, ai_controlled, int(enemy_count.value), friendly_total, " (includes 1 additional VIP)" if has_vip else ""]
	start_button.text = "START %d FRIENDLY VS %d ENEMIES — %s — %s" % [friendly_total, int(enemy_count.value), map_label, objective_label.to_upper()]

func _on_generation_toggled(enabled: bool) -> void:
	map_size_option.disabled = not enabled
	_refresh_seed_controls()
	_update_summary(0.0)

func _on_auto_seed_toggled(enabled: bool) -> void:
	if enabled:
		_prepare_new_seed()
	_refresh_seed_controls()

func _prepare_new_seed() -> void:
	seed_input.value = _seed_rng.randi_range(1, int(seed_input.max_value))


func _refresh_seed_controls() -> void:
	auto_seed_toggle.disabled = not generated_map_toggle.button_pressed
	seed_input.editable = generated_map_toggle.button_pressed and not auto_seed_toggle.button_pressed

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
		MissionCatalog.create_mission(objective_option.selected, int(enemy_count.value), vip_toggle.button_pressed),
		difficulty_option.selected
	)
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	queue_free()
