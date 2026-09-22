extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var bar := UnitWorldBar.new()
	bar.extract_button = Button.new()
	bar.add_child(bar.extract_button)
	bar._turn_manager = TurnManager.new()
	bar.add_child(bar._turn_manager)
	var unit := TacticalUnit.new()
	bar._target_unit = unit
	root.add_child(bar)
	bar._refresh_extract_button()
	unit.free()
	bar._refresh_extract_button()
	assert(not bar.extract_button.visible)
	print("[UnitWorldBar] PASSED — freed unit does not enter typed player array lookup")
	bar.queue_free()
	quit()
