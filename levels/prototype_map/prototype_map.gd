extends Node3D

@onready var mouse_raycaster: MouseRaycaster = $MouseRaycaster

func _ready() -> void:
	# Hook into our custom signal using Godot 4 callables
	mouse_raycaster.floor_clicked.connect(_on_floor_clicked)
	print("Sandbox initialization complete. Click anywhere on the floor!")

func _on_floor_clicked(click_position: Vector3) -> void:
	print("Laser connection successful! Ground struck at coordinate: ", click_position)
