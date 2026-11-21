extends Node2D

const Map = preload("res://resources/maps/le_hameau.gd")
const MEADOW := Color("#91ba53")
const WOOD_FLOOR := Color("#609747")
const CLEARING := Color("#d0ad69")
const RIVER := Color("#267fa8")
const HOUSES := [
	[Vector2(228, 153), Color("#cb624c"), Color("#f09863")],
	[Vector2(294, 161), Color("#5c83a8"), Color("#85bcca")],
	[Vector2(282, 217), Color("#be7850"), Color("#f4b76b")],
]

@export_enum("Surfaces", "Détails", "Objets", "Effets") var layer := 0

var _water_time := 0.0


func _ready() -> void:
	set_process(layer == 3)


func _process(delta: float) -> void:
	var previous_frame := floori(_water_time * 10.0)
	_water_time = fmod(_water_time + delta, 120.0)
	if floori(_water_time * 10.0) != previous_frame:
		queue_redraw()


func _draw() -> void:
	match layer:
		0: _draw_surfaces()
		1: _draw_details()
		2: _draw_objects()
		3: _draw_water()


func _draw_surfaces() -> void:
	draw_rect(Rect2(Vector2.ZERO, Map.SIZE), MEADOW)
	# Les taches restent larges et espacées pour laisser respirer la prairie.
	for patch: Array in [
		[Vector2(105, 142), Vector2(93, 43), Color("#9ec35c")],
		[Map.DRY_CENTER, Vector2(87, 39), Color("#a3c562")],
		[Vector2(323, 59), Vector2(118, 49), Color("#a1c660")],
		[Vector2(311, 316), Vector2(124, 39), Color("#85b352")],
		[Vector2(548, 277), Vector2(76, 38), Color("#a4c567")],
	]:
		_patch(patch[0], patch[1], patch[2])
	for wood: Array in Map.WOODS:
		draw_colored_polygon(PackedVector2Array(wood), WOOD_FLOOR)
	draw_colored_polygon(PackedVector2Array(Map.CLEARING), CLEARING)
	var road := PackedVector2Array(Map.ROAD)
	draw_polyline(road, Color("#b89758"), Map.ROAD_WIDTH)
	draw_polyline(road, Color("#e3c484"), 6.0)
	for path: Array in [
		[Vector2(241, 174), Vector2(240, 182), Vector2(244, 188)],
		[Vector2(306, 182), Vector2(304, 193), Vector2(306, 203)],
		[Vector2(295, 239), Vector2(312, 242), Vector2(320, 230), Vector2(318, 206), Vector2(320, 201)],
	]:
		draw_polyline(PackedVector2Array(path), Color("#e3c484"), 4.0)
	_river_band(-1, 1, 6.0, Color("#6e9250"))
	_river_band(-1, 1, 3.0, Color("#d4bf79"))
	_river_band(-1, 1, 0.0, Color("#49b4c1"))
	_river_band(-0.80, 0.83, 0.0, Color("#339cba"))
	_river_band(-0.53, 0.62, 0.0, RIVER)


func _patch(center: Vector2, size: Vector2, color: Color) -> void:
	var outline := PackedVector2Array([
		Vector2(-1, 0.14), Vector2(-0.83, -0.48), Vector2(-0.46, -0.72),
		Vector2(-0.25, -0.96), Vector2(0.39, -0.78), Vector2(0.80, -0.39),
		Vector2(1, 0.14), Vector2(0.72, 0.66), Vector2(0.18, 0.79),
		Vector2(-0.34, 0.65), Vector2(-0.67, 0.87),
	])
	for i in outline.size():
		outline[i] = (center + outline[i] * size).round()
	var rounded := PackedVector2Array()
	for i in outline.size():
		var next := outline[(i + 1) % outline.size()]
		rounded.append(outline[i].lerp(next, 0.22).round())
		rounded.append(outline[i].lerp(next, 0.78).round())
	draw_colored_polygon(rounded, color)


func _river_band(left: float, right: float, margin: float, color: Color) -> void:
	var outline := PackedVector2Array()
	for y in range(0, int(Map.SIZE.y) + 1, 3):
		outline.append(Vector2(roundf(Map.river_center(y) + left * Map.river_half_width(y) - margin), y))
	for y in range(int(Map.SIZE.y), -1, -3):
		outline.append(Vector2(roundf(Map.river_center(y) + right * Map.river_half_width(y) + margin), y))
	draw_colored_polygon(outline, color)


func _draw_details() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 814
	for i in 960:
		var p := Vector2(rng.randi_range(0, int(Map.SIZE.x) - 1), rng.randi_range(0, int(Map.SIZE.y) - 1))
		var terrain := Map.terrain_at(p)
		if terrain == Map.WATER:
			continue
		if terrain == Map.VILLAGE:
			_rect(p, 2, 1, Color("#bd995e"))
		elif terrain == Map.FOREST:
			_rect(p, 3, 1, Color("#548640"))
		else:
			_rect(p, rng.randi_range(1, 4), 1, Color("#80aa4b"))
			if i % 13 == 0:
				_rect(p + Vector2(1, -2), 1, 2, Color("#567f3b"))
				_rect(p + Vector2(1, -3), 2, 1, Color("#fff3ae") if i % 2 else Color("#f6b8b6"))
			elif i % 7 == 0:
				_rect(p + Vector2(0, -2), 1, 2, Color("#6e9b49"))
				_rect(p + Vector2(2, -3), 1, 3, Color("#759f46"))
	for y: int in [21, 44, 83, 125, 151, 201, 230, 258, 293, 324, 345]:
		var side := -1.0 if y % 2 == 0 else 1.0
		var x := roundf(Map.river_center(y) + side * (Map.river_half_width(y) + 3.0))
		_rect(Vector2(x - 2, y + 1), 6, 2, Color("#729453"))
		_rect(Vector2(x - 1, y - 3), 1, 5, Color("#547748"))
		_rect(Vector2(x + 1, y - 5), 1, 6, Color("#557d47"))
		_rect(Vector2(x + 3, y - 2), 1, 4, Color("#7e9747"))
		_rect(Vector2(x + 1, y - 6), 1, 2, Color("#ad824d"))
	for p: Vector2 in [Vector2(145, 121), Vector2(177, 265), Vector2(378, 120),
			Vector2(354, 304), Vector2(515, 41), Vector2(555, 258), Vector2(500, 318)]:
		_rect(p + Vector2(-1, 3), 11, 3, Color("#709c4b"))
		_rect(p, 8, 5, Color("#7e8675"))
		_rect(p + Vector2(1, -1), 5, 3, Color("#b6bd9f"))
		_rect(p + Vector2(5, 3), 3, 2, Color("#626f63"))


func _draw_objects() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 178
	for y in range(0, int(Map.SIZE.y), 11):
		for x in range(0, int(Map.SIZE.x), 12):
			var point := Vector2(x + rng.randi_range(-4, 4), y + rng.randi_range(-4, 4))
			if Map.terrain_at(point) == Map.FOREST and rng.randf() > 0.14:
				_tree(point, rng.randi_range(5, 8), rng.randf() > 0.43)
	for x in range(224, 265, 5):
		_rect(Vector2(x, 222), 5, 2, Color("#a27c46"))
		_rect(Vector2(x, 220), 2, 5, Color("#eed294"))
	for p: Vector2 in [Vector2(222, 214), Vector2(262, 214), Vector2(338, 221), Vector2(348, 218)]:
		_tree(p, 4, true)
	for house: Array in HOUSES:
		_house(house[0], house[1], house[2])
	for p: Vector2 in [Vector2(263, 177), Vector2(266, 179), Vector2(322, 232)]:
		_rect(p, 4, 4, Color("#8a664c"))
		_rect(p + Vector2(1, 0), 2, 2, Color("#d0a363"))


func _tree(p: Vector2, radius: int, broadleaf: bool) -> void:
	var r := float(radius)
	draw_circle(p + Vector2(2, 3), r, Color("#46783e"))
	if broadleaf:
		draw_circle(p, r, Color("#2a7149"))
		draw_circle(p + Vector2(-2, -2), r - 2.0, Color("#419656"))
		_rect(p + Vector2(-3, -3), 4, 2, Color("#6daf59"))
		_rect(p + Vector2(1, 2), 2, 1, Color("#54a15a"))
	else:
		draw_circle(p, r, Color("#225e4e"))
		draw_circle(p + Vector2(-1, -2), r - 2.0, Color("#348060"))
		_rect(p + Vector2(-1, -3), 2, 5, Color("#56a076"))
		_rect(p + Vector2(-3, 0), 6, 1, Color("#56a076"))


func _house(p: Vector2, roof: Color, light: Color) -> void:
	_rect(p + Vector2(3, 5), 25, 19, Color("#ae8b57"))
	_rect(p + Vector2(1, 1), 24, 21, Color("#694e45"))
	_rect(p + Vector2(2, 2), 22, 19, Color("#f1d8a2"))
	_rect(p + Vector2(10, 16), 5, 5, Color("#795847"))
	_rect(p + Vector2(4, 16), 3, 2, Color("#507d85"))
	_rect(p + Vector2(17, 16), 3, 2, Color("#507d85"))
	_rect(p, 26, 16, Color("#704849"))
	_rect(p + Vector2(1, 1), 24, 7, light)
	_rect(p + Vector2(1, 8), 24, 7, roof)
	for x in range(3, 24, 4):
		_rect(p + Vector2(x, 5), 2, 1, roof)
		_rect(p + Vector2(x - 1, 11), 2, 1, roof.darkened(0.17))
	_rect(p + Vector2(1, 7), 24, 1, light.lightened(0.22))
	_rect(p + Vector2(18, 2), 4, 5, Color("#8d6f64"))
	_rect(p + Vector2(18, 2), 4, 2, Color("#eac1a0"))


func _draw_water() -> void:
	var frame := floorf(_water_time * 10.0) / 10.0
	for i in 43:
		var y := fposmod(i * 37.0 + frame * 6.0, Map.SIZE.y)
		var across := sin(i * 2.76) * 0.72
		var p := Vector2(Map.river_center(y) + across * Map.river_half_width(y), y).round()
		var alpha := (0.5 + 0.5 * sin(i * 1.6 + frame * TAU / 4.0)) * 0.40
		_rect(p, 3 + i % 6, 1, Color(0.68, 0.96, 0.93, alpha))


func _rect(p: Vector2, width: int, height: int, color: Color) -> void:
	draw_rect(Rect2(p, Vector2(width, height)), color)
