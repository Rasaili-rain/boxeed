extends Control

@onready var _grid: GridContainer = $VBoxContainer/GridContainer

func _ready() -> void:
	for i in range(LevelManager.LEVELS.size()):
		var btn := Button.new()
		btn.text = "Level %d" % (i + 1)
		btn.custom_minimum_size = Vector2(80, 80)
		btn.disabled = i > LevelManager.highest_unlocked
		var idx := i
		btn.pressed.connect(func(): LevelManager.go_to_level(idx))
		_grid.add_child(btn)


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
