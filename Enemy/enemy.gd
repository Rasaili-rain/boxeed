extends CharacterBody2D

@export var speed: float = 80.0
@export var start_direction: Vector2 = Vector2(1, 0.7)
@export var sweep_speed: float = 1.2
@export var sweep_amplitude: float = 15.0
@export var search_duration: float = 4.0
@export var waypoint_radius: float = 4.0
@export var roam_radius: float = 80.0

enum State {ROAM,CHASE,SEARCH}

var _state: State = State.ROAM

var _facing: Vector2 = Vector2.RIGHT
var _sweep_t: float = 0.0
var _cone_offset_rad: float = 0.0

var _last_known_pos: Vector2 = Vector2.ZERO

var _search_angles: Array = []
var _search_step: int = 0

var _waypoint: Vector2 = Vector2.ZERO

var _stuck_timer: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _cone: LightCone = $VisionCone
@onready var _waypoint_timer: Timer = $WaypointTimer
@onready var _scan_timer: Timer = $ScanTimer
@onready var _search_timer: Timer = $SearchTimer
@onready var _nav_ray: RayCast2D = $NavigationRay

func _ready() -> void:
	_facing = start_direction.normalized()

	_cone.cone_range = 130.0
	_cone.cone_angle = 70.0

	var area := _cone.get_node("Area2D")

	area.body_entered.connect(_on_cone_body_entered)

	_waypoint_timer.timeout.connect(_pick_waypoint)
	_scan_timer.timeout.connect(_on_scan_timer)

	_search_timer.one_shot = true
	_search_timer.timeout.connect(_on_search_step)

	_pick_waypoint()

func _physics_process(delta: float) -> void:
	_update_sweep(delta)

	match _state:
		State.ROAM:_do_roam(delta)
		State.CHASE:_do_chase()
		State.SEARCH:_do_search()

	_cone.rotation = _facing.angle() + _cone_offset_rad


func _do_roam(delta: float) -> void:
	var to_wp := _waypoint - global_position

	if to_wp.length() < waypoint_radius:
		_pick_waypoint()
		return
	_stuck_timer += delta
	if _stuck_timer > 0.5:
		_stuck_timer = 0.0
		if global_position.distance_to(_last_pos) < 2.0: _pick_waypoint()
		_last_pos = global_position
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
	_facing = velocity.normalized()
	_play_walk_animation(_facing)

func _do_search() -> void:
	velocity = Vector2.ZERO


func _pick_waypoint() -> void:
	for _i in range(8):
		var angle := randf() * TAU
		var candidate := global_position + Vector2.RIGHT.rotated(angle) * roam_radius
		_nav_ray.target_position = candidate - global_position
		_nav_ray.force_raycast_update()
		if not _nav_ray.is_colliding():
			_waypoint = candidate
			return

	# fallback escape direction
	var escape := -_facing.rotated(PI * 0.5)

	_waypoint = global_position + escape * roam_radius

func _on_scan_timer() -> void:
	if _state == State.ROAM: _pick_waypoint()


func _enter_chase(pos: Vector2) -> void:
	_last_known_pos = pos
	_state = State.CHASE


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

	_facing = Vector2.RIGHT.rotated(_search_angles[0])
	_play_walk_animation(_facing)
	_search_timer.start(search_duration / _search_angles.size())

func _on_search_step() -> void:
	if _state != State.SEARCH: return
	_search_step += 1

	if _search_step >= _search_angles.size():
		_state = State.ROAM
		_pick_waypoint()
		return

	var a: float = _search_angles[_search_step]
	_facing = Vector2.RIGHT.rotated(a)
	_play_walk_animation(_facing)
	_search_timer.start(search_duration / _search_angles.size())


func _on_cone_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	if body.is_dead:return
	if body.is_boxed:return
	if body.is_morphing:return

	_last_known_pos = body.global_position
	_enter_chase(_last_known_pos)
	body.die()


func _update_sweep(delta: float) -> void:
	match _state:
		State.ROAM:
			_sweep_t += delta * sweep_speed
			_cone_offset_rad = sin(_sweep_t) * deg_to_rad(sweep_amplitude)
		State.CHASE, State.SEARCH:
			_cone_offset_rad = 0.0


func _play_walk_animation(dir: Vector2) -> void:
	var anim: String
	if abs(dir.x) >= abs(dir.y): anim = "move_right" if dir.x > 0 else "move_left"
	else: anim = "move_down" if dir.y > 0 else "move_up"

	if _sprite.animation != anim: _sprite.play(anim)
