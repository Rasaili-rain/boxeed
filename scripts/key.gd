extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)


# the key is picked by the player ie key checks for the player
func _on_body_entered(body):
	if body.is_in_group("player"):
		GameState.collect_key()
		queue_free()
