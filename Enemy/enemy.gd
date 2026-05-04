extends CharacterBody2D

@export var speed : float = 80.0
@export var start_direction : Vector2 = Vector2(1, 0.7)

@export var cone_range         : float = 130.0
@export var cone_half_angle    : float = 35.0
@export var sweep_speed        : float = 1.2
@export var sweep_amplitude    : float = 15.0
@export var cone_color_patrol  : Color = Color(1.00, 1.00, 0.00, 0.22)
@export var cone_color_alert   : Color = Color(1.00, 0.00, 0.00, 0.50)

@export var search_duration    : float = 4.0
@export var waypoint_radius    : float = 4.0   # how close = "reached"
@export var roam_radius        : float = 80.0  # how far waypoints spawn

enum State { ROAM, CHASE, SEARCH }
var _state : State = State.ROAM

var _facing          : Vector2 = Vector2.RIGHT
var _sweep_t         : float   = 0.0
var _cone_offset_rad : float   = 0.0
var _last_known_pos  : Vector2 = Vector2.ZERO
var _search_angles   : Array   = []
var _search_step     : int     = 0
var _waypoint        : Vector2 = Vector2.ZERO
var _stuck_timer     : float   = 0.0
var _last_pos        : Vector2 = Vector2.ZERO

@onready var _sprite        : AnimatedSprite2D = $AnimatedSprite2D
@onready var _cone_node     : Node2D           = $VisionCone
@onready var _ray           : RayCast2D        = $VisionRay
@onready var _waypoint_timer: Timer            = $WaypointTimer
@onready var _scan_timer    : Timer            = $ScanTimer
@onready var _search_timer  : Timer            = $SearchTimer


func _ready() -> void:
	_facing = start_direction.normalized()
	velocity = _facing * speed

	_waypoint_timer.timeout.connect(_pick_waypoint)
	_scan_timer.timeout.connect(_on_scan_timer)
	_search_timer.one_shot = true
	_search_timer.timeout.connect(_on_search_step)

	_cone_node.draw.connect(_draw_cone)
	_pick_waypoint()


func _physics_process(delta: float) -> void:
	_update_sweep(delta)
	_check_vision()

	match _state:
		State.ROAM:   _do_roam(delta)
		State.CHASE:  _do_chase()
		State.SEARCH: _do_search()

	_cone_node.queue_redraw()


# ── movement states ───────────────────────────────────────────────

func _do_roam(delta: float) -> void:
	var to_wp := _waypoint - global_position

	# reached waypoint — pick a new one
	if to_wp.length() < waypoint_radius:
		_pick_waypoint()
		return

	# stuck check — if we barely moved in 0.5s, pick new waypoint
	_stuck_timer += delta
	if _stuck_timer > 0.5:
		_stuck_timer = 0.0
		if global_position.distance_to(_last_pos) < 2.0:
			_pick_waypoint()
		_last_pos = global_position

	# steer toward waypoint, slide along walls naturally
	velocity = to_wp.normalized() * speed
	move_and_slide()

	if velocity.length() > 1.0:
		_facing = velocity.normalized()
		_play_walk_animation(_facing)


func _do_chase() -> void:
	var to_lkp := _last_known_pos - global_position
	if to_lkp.length() <= 8.0:
		_enter_search()
		return
	velocity = to_lkp.normalized() * speed * 1.4
	move_and_slide()
	_facing = to_lkp.normalized()
	_play_walk_animation(_facing)


func _do_search() -> void:
	velocity = Vector2.ZERO


# ── waypoint picking ──────────────────────────────────────────────

func _pick_waypoint() -> void:
	# try up to 8 random directions, pick first one not blocked by wall
	for _i in range(8):
		var angle := randf() * TAU
		var candidate := global_position + Vector2(cos(angle), sin(angle)) * roam_radius
		_ray.target_position = candidate - global_position
		_ray.force_raycast_update()
		if not _ray.is_colliding():
			_waypoint = candidate
			return
	# all blocked — just move away from current facing (corner escape)
	var escape := -_facing.rotated(PI * 0.5)
	_waypoint = global_position + escape * roam_radius


func _on_scan_timer() -> void:
	if _state == State.ROAM:
		_pick_waypoint()


# ── state transitions ─────────────────────────────────────────────

func _enter_chase(lkp: Vector2) -> void:
	_last_known_pos = lkp
	_state = State.CHASE
	_waypoint_timer.stop()


func _enter_search() -> void:
	velocity = Vector2.ZERO
	_state = State.SEARCH
	_search_step = 0

	var base := _facing.angle()
	_search_angles = [
		base - deg_to_rad(sweep_amplitude * 1.5),
		base,
		base + deg_to_rad(sweep_amplitude * 1.5),
		base,
	]
	_facing = Vector2(cos(_search_angles[0]), sin(_search_angles[0]))
	_play_walk_animation(_facing)
	_search_timer.start(search_duration / _search_angles.size())


func _on_search_step() -> void:
	if _state != State.SEARCH:
		return
	_search_step += 1
	if _search_step >= _search_angles.size():
		_state = State.ROAM
		velocity = _facing * speed
		_pick_waypoint()
		_waypoint_timer.start()
		return
	var a :float= _search_angles[_search_step]
	_facing = Vector2(cos(a), sin(a))
	_play_walk_animation(_facing)
	_search_timer.start(search_duration / _search_angles.size())


# ── vision ────────────────────────────────────────────────────────

func _check_vision() -> void:
	var player := _get_player()
	if player == null or player.is_dead:
		return
	if player.is_boxed or player.is_morphing:
		return
	if not _is_in_cone(player.global_position):
		return

	# check ray — don't detect through walls
	_ray.target_position = player.global_position - global_position
	_ray.force_raycast_update()
	if _ray.is_colliding():
		var hit := _ray.get_collider()
		if hit != player:
			return

	_last_known_pos = player.global_position
	_enter_chase(_last_known_pos)
	player.die()


func _is_in_cone(target_pos: Vector2) -> bool:
	var to_target := target_pos - global_position
	if to_target.length() > cone_range:
		return false
	var diff := absf(angle_difference(_facing.angle() + _cone_offset_rad, to_target.angle()))
	return diff <= deg_to_rad(cone_half_angle)


# ── sweep ─────────────────────────────────────────────────────────

func _update_sweep(delta: float) -> void:
	match _state:
		State.ROAM:
			_sweep_t += delta * sweep_speed
			_cone_offset_rad = sin(_sweep_t) * deg_to_rad(sweep_amplitude)
		State.CHASE, State.SEARCH:
			_cone_offset_rad = 0.0


# ── helpers ───────────────────────────────────────────────────────

func _play_walk_animation(dir: Vector2) -> void:
	var anim : String
	if abs(dir.x) >= abs(dir.y):
		anim = "move_right" if dir.x > 0 else "move_left"
	else:
		anim = "move_down" if dir.y > 0 else "move_up"
	if _sprite.animation != anim:
		_sprite.play(anim)


func _draw_cone() -> void:
	var segments   : int   = 28
	var half_rad   : float = deg_to_rad(cone_half_angle)
	var base_angle : float = _facing.angle() + _cone_offset_rad
	var col        : Color = cone_color_alert if _state != State.ROAM else cone_color_patrol

	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(segments + 1):
		var t     : float = float(i) / float(segments)
		var angle : float = base_angle - half_rad + t * (half_rad * 2.0)
		points.append(Vector2(cos(angle), sin(angle)) * cone_range)
	_cone_node.draw_colored_polygon(points, col)


func _get_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if players.size() > 0 else null
