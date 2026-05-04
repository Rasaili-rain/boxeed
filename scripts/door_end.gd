extends Area2D

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _blocker: StaticBody2D = $StaticBody2D

func _ready():
	body_entered.connect(_on_body_entered)
	# listen for key pickup from anywhere in the tree
	GameState.key_collected.connect(_on_key_collected)

func _on_key_collected():
	_blocker.get_child(0).set_deferred("disabled", true)
	_sprite.play("open")
	_sprite.animation_finished.connect(_on_open_finished, CONNECT_ONE_SHOT)

func _on_body_entered(body):
	if body.is_in_group("player"):
		if GameState.has_key:
			LevelManager.complete_current_level()
		else:
			print("Door is locked! Find the key.")

func _on_open_finished():
	pass  # animation done, door is already open visually
