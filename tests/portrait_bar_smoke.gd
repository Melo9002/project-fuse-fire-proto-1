extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var level = load("res://levels/prototype_map/prototype_map.tscn").instantiate() as BattleLevel
	level.configure(3, 1)
	root.add_child(level)
	await create_timer(0.15).timeout

	var turns = level.turn_manager
	var battle = level.battle_controller
	var bar = level.get_node("Visualizers/BattleUI/UnitPortraitBar") as UnitPortraitBar
	check(bar.portraits.size() == 3, "Portrait count matches the player roster")
	check(bar.portraits[0].display_state == UnitPortrait.DisplayState.SELECTED, "Initial active unit is highlighted")

	bar.portraits[1]._on_pressed()
	check(turns.active_unit == turns.player_units[1], "Clicking a portrait selects its unit")
	check(bar.portraits[1].display_state == UnitPortrait.DisplayState.SELECTED, "Portrait click updates selected state")

	battle._on_unit_clicked(turns.player_units[2])
	check(bar.portraits[2].display_state == UnitPortrait.DisplayState.SELECTED, "Battlefield selection updates the portrait")
	check(bar.portraits[1].display_state == UnitPortrait.DisplayState.READY, "Previous portrait returns to ready")

	turns.player_units[2].stats.consume_ap(2)
	check(bar.portraits[2].display_state == UnitPortrait.DisplayState.EXHAUSTED, "Zero AP shows exhausted state")
	check(bar.portraits[2].disabled, "Exhausted portrait cannot request selection")
	check(turns.active_unit == turns.player_units[2], "Task 3 does not add automatic cycling")

	var defeated_unit = turns.player_units[1]
	defeated_unit.stats.take_damage(1000)
	await process_frame
	check(bar.portraits.size() == 3, "Defeated unit keeps its portrait for battle history")
	check(bar.portraits[1].display_state == UnitPortrait.DisplayState.DEAD, "Defeated portrait shows dead state")
	check(bar.portraits[1].hp_label.text == "HP  0 / 100", "Portrait HP updates before removal")
	check(turns.player_units.size() == 2, "Defeat still removes the world unit from the roster")

	level.queue_free()
	await process_frame
	print("Portrait bar smoke: %d failure(s)" % failures)
	quit(1 if failures else 0)
