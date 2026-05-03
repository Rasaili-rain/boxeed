extends CharacterBody2D

# ── Speed ────────────────────────────────────────────────────
@export var speed : float = 80.0
@export var start_direction : Vector2 = Vector2(1, 0.7)

# ── Vision cone ──────────────────────────────────────────────
@export var cone_range             : float = 130.0
@export var cone_half_angle        : float = 35.0
@export var sweep_speed            : float = 1.2
@export var sweep_amplitude        : float = 15.0
@export var cone_color_patrol      : Color = Color(1.00, 1.00, 0.00, 0.22)
@export var cone_color_alert       : Color = Color(1.00, 0.00, 0.00, 0.50)

# ── Detection ────────────────────────────────────────────────
@export var detection_time    : float = 2.0
@export var search_duration   : float = 4.0

# =============================================================
enum State { ROAM, CHASE, SEARCH }
var _state : State = State.ROAM

var _facing          : Vector2 = Vector2.RIGHT
var _sweep_t         : float   = 0.0
var _cone_offset_rad : float   = 0.0
var _player_in_cone  : bool    = false
var _last_known_pos  : Vector2 = Vector2.ZERO
var _scan_angle_acc  : float   = 0.0

@onready var _sprite       : AnimatedSprite2D = $AnimatedSprite2D
@onready var _ray          : RayCast2D        = $VisionRay
@onready var _cone_node    : Node2D           = $VisionCone
@onready var _detect_timer : Timer            = $DetectionTimer
@onready var _search_timer : Timer            = $SearchTimer


# =============================================================
func _ready() -> void:
	velocity = start_direction.normalized() * speed

	_detect_timer.one_shot = true
	_detect_timer.timeout.connect(_on_detection_confirmed)

	_search_timer.one_shot = true
	_search_timer.timeout.connect(_on_search_done)

	_cone_node.draw.connect(_draw_cone)


# =============================================================
func _physics_process(delta: float) -> void:
	_update_sweep(delta)
	_check_vision()

	match _state:
		State.ROAM:   _do_roam()
		State.CHASE:  _do_chase()
		State.SEARCH: _do_search(delta)

	_cone_node.queue_redraw()


# =============================================================
#  ROAM  –  bounce off walls
# =============================================================
func _do_roam() -> void:
	move_and_slide()
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		velocity = velocity.bounce(col.get_normal()).rotated(randf_range(-0.08, 0.08))
	if velocity.length() > 1.0:
		_facing = velocity.normalized()
		_play_walk_animation(_facing)


# =============================================================
#  CHASE
# =============================================================
func _do_chase() -> void:
	var to_lkp : Vector2 = _last_known_pos - global_position
	if to_lkp.length() <= 8.0:
		_enter_search()
		return
	velocity = to_lkp.normalized() * speed * 1.4
	move_and_slide()
	_facing = to_lkp.normalized()
	_play_walk_animation(_facing)


func _enter_chase(lkp: Vector2) -> void:
	_last_known_pos = lkp
	_state = State.CHASE
	_detect_timer.stop()
	_player_in_cone = false


# =============================================================
#  SEARCH  –  spin in place, then go back to roaming
# =============================================================
func _do_search(delta: float) -> void:
	velocity = Vector2.ZERO
	_scan_angle_acc += delta * 1.5
	_facing = Vector2(cos(_scan_angle_acc), sin(_scan_angle_acc))
	_play_walk_animation(_facing)


func _enter_search() -> void:
	velocity = Vector2.ZERO
	_state = State.SEARCH
	_scan_angle_acc = _facing.angle()
	_search_timer.start(search_duration)


func _on_search_done() -> void:
	if _state == State.SEARCH:
		# Resume bouncing in the direction we're now facing
		velocity = _facing * speed
		_state = State.ROAM


# =============================================================
#  VISION
# =============================================================
#func _check_vision() -> void:
	#var player := _get_player()
	#if player == null or player.is_dead or player.is_boxed:
		#_on_player_lost()
		#return
#
	#var to_player : Vector2 = player.global_position - global_position
	#if to_player.length() > cone_range:
		#_on_player_lost()
		#return
#
	#var cone_dir  : Vector2 = Vector2(
		#cos(_facing.angle() + _cone_offset_rad),
		#sin(_facing.angle() + _cone_offset_rad)
	#)
	#var angle_diff : float = abs(rad_to_deg(to_player.angle_to(cone_dir)))
	#if angle_diff > cone_half_angle:
		#_on_player_lost()
		#return
#
	#_ray.target_position = to_player
	#_ray.force_raycast_update()
	#if _ray.is_colliding():
		#_on_player_lost()
		#return
#
	## ── Player spotted ──
	#_last_known_pos = player.global_position
	#print("player is spotted")
	#if not _player_in_cone:
		#_player_in_cone = true
		#_detect_timer.wait_time = detection_time
		#_detect_timer.start()
		
func _check_vision() -> void:
	var player := _get_player()
	if player == null:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist < cone_range:
		_last_known_pos = player.global_position
		if not _player_in_cone:
			_player_in_cone = true
			_detect_timer.wait_time = detection_time
			_detect_timer.start()
	else:
		_on_player_lost()


func _on_player_lost() -> void:
	if not _player_in_cone:
		return
	_player_in_cone = false
	_detect_timer.stop()


func _on_detection_confirmed() -> void:
	var player := _get_player()
	if player != null and not player.is_dead:
		_enter_chase(_last_known_pos)
		player.die()


# =============================================================
#  SWEEP
# =============================================================
func _update_sweep(delta: float) -> void:
	match _state:
		State.ROAM:
			_sweep_t += delta * sweep_speed
			_cone_offset_rad = sin(_sweep_t) * deg_to_rad(sweep_amplitude)
		State.CHASE, State.SEARCH:
			_cone_offset_rad = 0.0


# =============================================================
#  ANIMATION
# =============================================================
func _play_walk_animation(dir: Vector2) -> void:
	var anim : String
	if abs(dir.x) >= abs(dir.y):
		anim = "move_right" if dir.x > 0 else "move_left"
	else:
		anim = "move_down" if dir.y > 0 else "move_up"
	if _sprite.animation != anim:
		_sprite.play(anim)


# =============================================================
#  CONE DRAW
# =============================================================
func _draw_cone() -> void:
	var segments   : int   = 28
	var half_rad   : float = deg_to_rad(cone_half_angle)
	var base_angle : float = _facing.angle() + _cone_offset_rad
	var col : Color = cone_color_alert if _state != State.ROAM else cone_color_patrol

	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(segments + 1):
		var t     : float = float(i) / float(segments)
		var angle : float = base_angle - half_rad + t * (half_rad * 2.0)
		points.append(Vector2(cos(angle), sin(angle)) * cone_range)
	_cone_node.draw_colored_polygon(points, col)


# =============================================================
#  UTILITY
# =============================================================
func _get_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if players.size() > 0 else null
