extends CanvasLayer

@onready var _panel       : Control = $Control
@onready var _retry       : Button  = $Control/PanelContainer/VBoxContainer/RetryButton
@onready var _menu        : Button  = $Control/PanelContainer/VBoxContainer/MenuButton

func _ready() -> void:
	visible = false
	_panel.visible = false
	_retry.pressed.connect(_on_retry)
	_menu.pressed.connect(_on_menu)

func show_screen() -> void:
	visible = true
	_panel.visible = true
	await get_tree().process_frame
	get_tree().paused = true

func _on_retry() -> void:
	print("retry pressed")
	visible = false        
	get_tree().paused = false
	LevelManager.reload_current()

func _on_menu() -> void:
	print("menu pressed")
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://LevelManager/main_menu.tscn")
