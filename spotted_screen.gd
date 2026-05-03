extends CanvasLayer

@onready var _panel   : Control = $Control
@onready var _retry   : Button  = $Control/PanelContainer/VBoxContainer/RetryButton
@onready var _menu    : Button  = $Control/PanelContainer/VBoxContainer/MenuButton

func _ready() -> void:
	add_to_group("spotted_screen")
	_panel.visible = false
	_retry.pressed.connect(_on_retry)
	_menu.pressed.connect(_on_menu)

func show_screen() -> void:
	_panel.visible = true
	get_tree().paused = true   # freeze everything while the screen is up

func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")
