extends CanvasLayer

@onready var _icons_row: HBoxContainer = $MarginContainer/VBoxContainer/BoxUsesRow
@onready var _bar: ProgressBar = $MarginContainer/VBoxContainer/Bar

var _icons: Array = []
var _prev_state := ""

# Call this once from the player after _ready
func setup(max_uses: int, icon_texture: Texture2D):
	for child in _icons_row.get_children():
		child.queue_free()
	_icons.clear()
	for i in max_uses:
		var tex := TextureRect.new()
		tex.texture = icon_texture
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		tex.custom_minimum_size = Vector2(10, 10)
		_icons_row.add_child(tex)
		_icons.append(tex)
	# Fixed bar width regardless of icon count
	_bar.custom_minimum_size = Vector2(60, 5)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func update(uses_left: int, box_timer: float, box_duration: float,
			cooldown_timer: float, morph_cooldown: float,
			is_boxed: bool, is_morphing: bool):
	_update_icons(uses_left)
	_update_bar(box_timer, box_duration, cooldown_timer, morph_cooldown, is_boxed, is_morphing)

func _update_icons(uses_left: int):
	for i in _icons.size():
		_icons[i].modulate = Color(1, 1, 1, 1) if i < uses_left else Color(0.2, 0.2, 0.2, 0.4)

func _update_bar(box_timer: float, box_duration: float,
				 cooldown_timer: float, morph_cooldown: float,
				 is_boxed: bool, is_morphing: bool):
	var state := "ready"
	if is_morphing:           state = "morphing"
	elif is_boxed:            state = "boxed"
	elif cooldown_timer > 0:  state = "cooldown"

	if state != _prev_state:
		_prev_state = state
		match state:
			"morphing": _set_bar_color(Color(1, 0.85, 0.3))
			"boxed":    _set_bar_color(Color(0.55, 0.36, 0.18))
			"cooldown": _set_bar_color(Color(0.35, 0.35, 0.35))
			"ready":    _set_bar_color(Color(0.3, 1, 0.45))

	match state:
		"morphing": _bar.value = 100.0
		"boxed":    _bar.value = (box_timer / box_duration) * 100.0
		"cooldown": _bar.value = (1.0 - cooldown_timer / morph_cooldown) * 100.0
		"ready":    _bar.value = 100.0

func _set_bar_color(color: Color):
	var style := StyleBoxFlat.new()
	style.bg_color = color
	_bar.add_theme_stylebox_override("fill", style)
