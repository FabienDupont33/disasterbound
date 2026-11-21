extends Control

const Technologies = preload("res://resources/balance/fire_technologies.gd")
const Progression = preload("res://scripts/progression/fire_progression.gd")
const LOCKED := Color("#557075")
const READY := Color("#83c6bd")
const OWNED := Color("#f4cc83")

signal node_selected(id: StringName)

var progression: Progression
var selected: StringName
var _zoom := 0.90
var _pan := Vector2.ZERO
var _press := Vector2.ZERO
var _dragging := false
var _moved := false
var _pulse := 0.0


func recenter() -> void:
	_zoom = 0.90
	_pan = -Technologies.CORE * _zoom
	queue_redraw()


func pulse() -> void:
	_pulse = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 2.0)
		queue_redraw()


func _screen(point: Vector2) -> Vector2:
	return (size * 0.5 + _pan + point * _zoom).round()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var old_zoom := _zoom
			var factor := 1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
			_zoom = clampf(_zoom * factor, 0.65, 1.85)
			var anchor: Vector2 = event.position - size * 0.5
			_pan = anchor - (anchor - _pan) * (_zoom / old_zoom)
			_limit_pan()
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press = event.position
				_dragging = true
				_moved = false
			elif _dragging:
				_dragging = false
				if not _moved:
					_pick(event.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if _moved or _press.distance_to(event.position) >= 4.0:
			_moved = true
			_pan += event.relative
			_limit_pan()
			queue_redraw()
		accept_event()


func _limit_pan() -> void:
	var limit := size * 0.65 * _zoom
	_pan = _pan.clamp(-limit, limit)


func _pick(point: Vector2) -> void:
	var closest := INF
	var match_id: StringName
	for id: StringName in Technologies.NODES:
		var node: Dictionary = Technologies.NODES[id]
		var distance := point.distance_to(_screen(node.pos))
		if distance < closest and distance <= 22.0 * _zoom:
			closest = distance
			match_id = id
	if match_id != &"":
		node_selected.emit(match_id)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0e1c23"))
	for y in range(7, int(size.y), 11):
		for x in range(5 + y % 7, int(size.x), 13):
			var dot := Color("#22343a") if (x * 7 + y * 3) % 5 == 0 else Color("#16282e")
			draw_rect(Rect2(x, y, 1, 1), dot)
	if progression == null:
		return
	var core := _screen(Technologies.CORE)
	for id: StringName in Technologies.NODES:
		var node: Dictionary = Technologies.NODES[id]
		var requirements: Dictionary = node.requires
		if requirements.is_empty():
			_edge(core, _screen(node.pos), true, id)
		for dependency: StringName in requirements:
			_edge(_screen(Technologies.NODES[dependency].pos), _screen(node.pos),
					progression.level(dependency) >= requirements[dependency], id)
	_badge(core, 21.0 * _zoom, 8, Color("#ec9b63"), Color("#653b33"))
	_fire_icon(core)
	_caption(core + Vector2(0, 32 * _zoom), "INCENDIE", Color("#ffd6a3"), 12)
	_caption(_screen(Vector2(-170, 100)), "VILLAGE", Color("#75979b"), 11)
	_caption(_screen(Vector2(153, -177)), "CANON À EAU", Color("#759b93"), 11)
	for id: StringName in Technologies.NODES:
		_draw_node(id)


func _edge(from: Vector2, to: Vector2, active: bool, id: StringName) -> void:
	var color := Color("#41605f") if active else Color("#293e47")
	draw_line(from, to, color, 2.0)
	if id == selected and _pulse > 0.0:
		var current := from.lerp(to, 1.0 - _pulse)
		draw_line(from, current, Color("#e5b26a"), 2.0)
		draw_rect(Rect2(current.round() - Vector2.ONE, Vector2(3, 3)), OWNED)


func _draw_node(id: StringName) -> void:
	var node: Dictionary = Technologies.NODES[id]
	var center := _screen(node.pos)
	var major: bool = node.max == 1
	var level := progression.level(id)
	var color := LOCKED
	if level > 0:
		color = OWNED
	elif progression.requirements_met(id):
		color = READY
	var radius := (17.0 if major else 12.0) * _zoom
	if id == selected:
		var halo := radius + 4.0 + _pulse * 8.0
		draw_arc(center, halo, 0.0, TAU, 24, Color(color, 0.5 + _pulse * 0.4), 1.0)
	var fill := Color("#5c4831") if level > 0 else Color("#20343c")
	_badge(center, radius, 6 if major else 8, color, fill)
	var text := "◆"
	if not major:
		text = "%d/%d" % [level, node.max]
	_caption(center + Vector2(0, 3), text, color, 10)
	_caption(center + Vector2(0, radius + 12), node.short, color, 10)


func _badge(center: Vector2, radius: float, sides: int, stroke: Color, fill: Color) -> void:
	var polygon := PackedVector2Array()
	for i in sides:
		polygon.append((center + Vector2.from_angle(TAU * i / sides - PI * 0.5) * radius).round())
	draw_colored_polygon(polygon, fill)
	polygon.append(polygon[0])
	draw_polyline(polygon, stroke, 2.0)


func _fire_icon(center: Vector2) -> void:
	var flame := PackedVector2Array([Vector2(-6, 5), Vector2(-7, 0), Vector2(-3, -6),
		Vector2(-2, -1), Vector2(3, -11), Vector2(7, -3), Vector2(7, 4), Vector2(3, 8), Vector2(-3, 8)])
	for i in flame.size():
		flame[i] = (center + flame[i] * _zoom).round()
	draw_colored_polygon(flame, Color("#f68e54"))
	draw_rect(Rect2(center + Vector2(-2, 1), Vector2(4, 5)), Color("#ffde99"))


func _caption(at: Vector2, caption: String, color: Color, font_size: int) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, (at - Vector2(width * 0.5, 0)).round(), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
