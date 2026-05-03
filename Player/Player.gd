extends CharacterBody2D

@export var speed := 120
@export var box_speed := 40
@export var morph_delay := 0.6
@export var box_duration := 3.0
@export var morph_cooldown := 8.0
@export var max_box_uses := 3
@export var box_icon: Texture2D = preload("res://Player/assets/box_icon.png")

var direction := "down"
var is_dead := false
var is_boxed := false
var is_morphing := false
var box_uses_left := max_box_uses
var _morph_timer := 0.0
var _box_timer := 0.0
var _cooldown_timer := 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _box_rect: Sprite2D = $BoxRect
@onready var _hud: CanvasLayer = $HUD


func _ready():
	box_uses_left = max_box_uses
	_hud.setup(max_box_uses, box_icon)

func _physics_process(delta):
	_tick_box(delta)

	var input := Vector2.ZERO
	input.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	input = input.normalized()

	var current_speed = box_speed if is_boxed else speed
	if is_morphing:
		velocity = velocity.lerp(Vector2.ZERO, 0.3)
	else:
		velocity = velocity.lerp(input * current_speed, 0.2)

	move_and_slide()

	if not is_boxed and not is_morphing:
		if input.x > 0: direction = "right"
		elif input.x < 0: direction = "left"
		elif input.y > 0: direction = "down"
		elif input.y < 0: direction = "up"

	update_animation(input)
	_hud.update(box_uses_left, _box_timer, box_duration,
				_cooldown_timer, morph_cooldown,
				is_boxed, is_morphing)

func _tick_box(delta):
	if _cooldown_timer > 0:
		_cooldown_timer -= delta

	if is_morphing:
		_morph_timer -= delta
		_sprite.visible = int(_morph_timer * 10) % 2 == 0
		if _morph_timer <= 0:
			_finish_morph()
		return

	if is_boxed:
		_box_timer -= delta
		# Early unbox on E press
		if Input.is_action_just_pressed("box_morph"):
			_unmorph()
			return
		if _box_timer <= 0:
			_unmorph()
		return

	if Input.is_action_just_pressed("box_morph"):
		_try_morph()
		
func _try_morph():
	if box_uses_left <= 0 or _cooldown_timer > 0 or is_dead:
		return
	is_morphing = true
	_morph_timer = morph_delay
	box_uses_left -= 1

func _finish_morph():
	is_morphing = false
	is_boxed = true
	_box_timer = box_duration
	# Swap visuals
	_sprite.visible = false
	_box_rect.visible = true

func _unmorph():
	is_boxed = false
	_cooldown_timer = morph_cooldown
	# Swap visuals back
	_sprite.visible = true
	_box_rect.visible = false
	

func restore_box_use():
	box_uses_left = min(box_uses_left + 1, max_box_uses)

func update_animation(input):
	if is_dead:
		_sprite.play("death")
		return
	if is_morphing or is_boxed:
		return
	if input != Vector2.ZERO:
		var new_anim = "walk_" + direction
		if _sprite.animation != new_anim:
			_sprite.play(new_anim)
	else:
		_sprite.play("idle_" + direction)
		
func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	update_animation(Vector2.ZERO)
	await get_tree().create_timer(0.8, false, false, true).timeout
	SpottedScreen.show_screen()
