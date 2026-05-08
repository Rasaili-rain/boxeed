@tool
class_name LightCone
extends Node2D

## ── Shape ────────────────────────────────────────────

@export_range(1, 360, 1)
var cone_angle: float = 60.0:
	set(v):
		cone_angle = v
		_update_cone()

@export_range(10, 2000, 10)
var cone_range: float = 200.0:
	set(v):
		cone_range = v
		_update_cone()

@export_range(3, 300, 1)
var ray_count: int = 60:
	set(v):
		ray_count = v
		_update_cone()

## ── Physics ──────────────────────────────────────────

@export_flags_2d_physics
var wall_layer: int = 2:
	set(v):
		wall_layer = v
		_update_cone()

## ── Colors ───────────────────────────────────────────

@export
var patrol_color: Color = Color(1.0, 0.95, 0.7, 0.35)

@export
var alert_color: Color = Color(1.0, 0.0, 0.0, 0.5)

@export
var alert_duration: float = 1.0

## ── Debug ────────────────────────────────────────────

@export
var show_rays: bool = false:
	set(v):
		show_rays = v
		queue_redraw()

@export
var show_hitpoints: bool = false:
	set(v):
		show_hitpoints = v
		queue_redraw()

@onready var polygon_visual: Polygon2D = $Polygon2D
@onready var area: Area2D = $Area2D
@onready var collision_polygon: CollisionPolygon2D = $Area2D/CollisionPolygon2D

var _space: PhysicsDirectSpaceState2D
var _last_points: PackedVector2Array = []

var _alert_timer: SceneTreeTimer

func _ready() -> void:
	_apply_color(patrol_color)

	if not Engine.is_editor_hint():
		area.body_entered.connect(_on_body_entered)

	_update_cone()

func _physics_process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_update_cone()

func _update_cone() -> void:
	if not is_inside_tree():
		return

	_space = get_world_2d().direct_space_state

	var pts := _cast_cone()

	_last_points = pts

	if pts.size() >= 3:
		if polygon_visual:
			polygon_visual.polygon = pts

		if collision_polygon:
			collision_polygon.polygon = pts

	queue_redraw()

func _apply_color(c: Color) -> void:
	if polygon_visual:
		polygon_visual.color = c

func set_alert() -> void:
	_apply_color(alert_color)

	if _alert_timer:
		_alert_timer.timeout.disconnect(_reset_color)

	_alert_timer = get_tree().create_timer(alert_duration)

	_alert_timer.timeout.connect(_reset_color)

func _reset_color() -> void:
	_apply_color(patrol_color)

func _cast_cone() -> PackedVector2Array:
	var pts := PackedVector2Array()

	pts.append(Vector2.ZERO)

	var half := cone_angle * 0.5
	var origin := global_position

	for i in range(ray_count + 1):
		var t := float(i) / float(ray_count)

		var angle: float = lerp(-half, half, t)
		var angle_rad := deg_to_rad(angle) + global_rotation

		var dir := Vector2.RIGHT.rotated(angle_rad)
		var target := origin + dir * cone_range

		var final_pos := target

		if _space:
			var q := PhysicsRayQueryParameters2D.create(origin, target)

			q.collision_mask = wall_layer
			q.exclude = [self]

			var hit := _space.intersect_ray(q)

			if not hit.is_empty():
				final_pos = hit.position

		pts.append(to_local(final_pos))

	if pts.size() < 3:
		return PackedVector2Array()

	return pts

func _draw() -> void:
	if not show_rays and not show_hitpoints:
		return

	for p in _last_points:
		if show_rays:
			draw_line(Vector2.ZERO, p, Color.RED, 1.0)

		if show_hitpoints:
			draw_circle(p, 3.0, Color.YELLOW)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if body.is_boxed or body.is_morphing:
		return

	set_alert()

	body.die()
