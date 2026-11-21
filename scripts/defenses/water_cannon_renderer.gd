extends Node2D

const Cannon = preload("res://scripts/defenses/water_cannon.gd")
const Map = preload("res://resources/maps/le_hameau.gd")
const CYAN := Color("#78e3eb")
const INK := Color("#243943")

var cannon: Cannon
var running := false
var preview_visible := false
var preview_valid := false
var preview_position := Vector2.ZERO
var preview_range := 0.0
var map_size := Map.SIZE
var time_scale := 1.0
@export var icon_only := false

var _display_angle := -PI / 2.0
var _phase := 0.0


func _process(delta: float) -> void:
	if icon_only:
		set_process(false)
		return
	delta *= time_scale
	if cannon != null and running:
		_display_angle = rotate_toward(_display_angle, cannon.angle, cannon.config.rotation_speed * delta)
		_phase = fmod(_phase + delta, 60.0)
	elif cannon == null:
		_display_angle = -PI / 2.0
	queue_redraw()


func _draw() -> void:
	if icon_only:
		_draw_sprite(Vector2.ZERO, Vector2.UP, 1.0)
		return
	if cannon != null:
		var fraction := cannon.hp / cannon.config.max_hp
		var direction := Vector2.from_angle(_display_angle)
		if running and cannon.spraying and fraction > 0.0:
			_draw_jet(cannon.position + direction * 9.0, cannon.impact)
		_draw_sprite(cannon.position, direction, fraction)
		if fraction > 0.0 and fraction < 0.999:
			_pixel(cannon.position + Vector2(-8, -13), Vector2(16, 3), INK)
			_pixel(cannon.position + Vector2(-7, -12), Vector2(roundf(14.0 * fraction), 1),
					Color("#f4c16b") if fraction > 0.35 else Color("#ef7b64"))
	elif preview_visible:
		var color := CYAN if preview_valid else Color("#ff8b79")
		_draw_range(preview_position, color)
		_draw_sprite(preview_position, Vector2.UP, 1.0, 0.66)
		if not preview_valid:
			var p := preview_position + Vector2(4, 4)
			draw_line(p, p + Vector2(5, 5), color, 1.0)
			draw_line(p + Vector2(5, 0), p + Vector2(0, 5), color, 1.0)


func _draw_range(p: Vector2, color: Color) -> void:
	var map_rect := Rect2(Vector2.ZERO, map_size)
	for i in 80:
		if i % 4 == 3:
			continue
		var start := (p + Vector2.from_angle(TAU * i / 80.0) * preview_range).round()
		var end := (p + Vector2.from_angle(TAU * (i + 1) / 80.0) * preview_range).round()
		if map_rect.has_point(start) and map_rect.has_point(end):
			draw_line(start, end, Color(color, 0.90), 1.0)


func _draw_sprite(p: Vector2, direction: Vector2, hp_fraction: float, opacity: float = 1.0) -> void:
	_pixel(p + Vector2(-6, -4), Vector2(15, 12), Color(0.07, 0.12, 0.12, opacity * 0.48))
	_pixel(p + Vector2(-7, -6), Vector2(14, 12), Color(INK, opacity))
	_pixel(p + Vector2(-6, -5), Vector2(12, 10), Color(Color("#5e7070"), opacity))
	_pixel(p + Vector2(-5, -4), Vector2(10, 8),
			Color(Color("#c09a56") if hp_fraction > 0.0 else Color("#514448"), opacity))
	for corner: Vector2 in [Vector2(-5, -4), Vector2(4, -4), Vector2(-5, 3), Vector2(4, 3)]:
		_pixel(p + corner, Vector2.ONE, Color(Color("#f0d295"), opacity * 0.85))
	var steel := Color("#3faeaf").lerp(Color("#865744"), 1.0 - hp_fraction)
	var tip := (p + direction * (9.0 if hp_fraction > 0.0 else 4.0)).round()
	draw_line(p, tip, Color(INK, opacity), 5.0)
	draw_line(p, tip, Color(steel, opacity), 3.0)
	_pixel(tip - Vector2.ONE, Vector2(2, 2), Color(CYAN if hp_fraction > 0.0 else INK, opacity))
	_pixel(p - Vector2(3, 3), Vector2(6, 6), Color(INK, opacity))
	_pixel(p - Vector2(2, 2), Vector2(4, 4), Color(steel, opacity))
	_pixel(p - Vector2(2, 2), Vector2(2, 1), Color(Color("#d6eee1"), opacity * hp_fraction))


func _draw_jet(start: Vector2, end: Vector2) -> void:
	var length := start.distance_to(end)
	if length < 2.0:
		return
	var axis := start.direction_to(end)
	var side := axis.orthogonal()
	draw_line(start.round(), end.round(), Color("#429ebe"), 2.0)
	draw_line(start.round(), end.round(), Color("#6bd0dd"), 1.0)
	for i in ceili(length / 6.0):
		var offset := fposmod(i * 6.0 + _phase * 108.0, length)
		var p := start + axis * offset + side * sin(offset * 0.23 + _phase * 20.0)
		draw_line(p.round(), (p + axis * minf(3.0, length - offset)).round(), CYAN, 2.0)
	for i in 8:
		var life := fposmod(_phase * 3.8 + i * 0.31, 1.0)
		var spread := Vector2.from_angle(i * 2.4) * (2.0 + life * 7.0)
		_pixel((end + spread).round(), Vector2.ONE * (2.0 if i % 3 == 0 else 1.0),
				Color(Color("#c8f9ed"), 1.0 - life))
	for i in 4:
		var rise := fposmod(_phase * 2.1 + i * 0.25, 1.0)
		var p := end + Vector2(sin(i * 4.0 + rise * 4.0) * 4.0, -2.0 - rise * 10.0)
		_pixel(p.round(), Vector2(3, 2), Color(0.88, 0.94, 0.88, (1.0 - rise) * 0.58))


func _pixel(p: Vector2, size: Vector2, color: Color) -> void:
	draw_rect(Rect2(p, size), color)
