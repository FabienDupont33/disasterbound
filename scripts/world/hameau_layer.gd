extends Node2D

const Map = preload("res://resources/maps/le_hameau.gd")
const Puzzle = preload("res://resources/maps/fire_puzzle.gd")
const MEADOW := Color("#91ba53")
const WOOD_FLOOR := Color("#609747")
const CLEARING := Color("#d0ad69")
const RIVER := Color("#267fa8")
const HOUSES := [
	[Color("#cb624c"), Color("#f09863")],
	[Color("#5c83a8"), Color("#85bcca")],
	[Color("#be7850"), Color("#f4b76b")],
	[Color("#6e875d"), Color("#b5bc80")],
]

@export_enum("Surfaces", "Détails", "Objets", "Effets") var layer := 0

var _water_time := 0.0
var _house_stages := PackedByteArray([0, 0, 0])
var map: Script = Map
var time_scale := 1.0


func use_map(new_map: Script) -> void:
	map = new_map
	_house_stages.resize(map.HOUSE_ORIGINS.size())
	_house_stages.fill(0)
	queue_redraw()


func set_house_stage(index: int, stage: int) -> void:
	if _house_stages[index] != stage:
		_house_stages[index] = stage
		queue_redraw()


func _ready() -> void:
	set_process(layer == 3)


func _process(delta: float) -> void:
	delta *= time_scale
	var previous_frame := floori(_water_time * 10.0)
	_water_time = fmod(_water_time + delta, 120.0)
	if floori(_water_time * 10.0) != previous_frame:
		queue_redraw()


func _draw() -> void:
	match layer:
		0: _draw_surfaces()
		1: _draw_details()
		2: _draw_objects()
		3:
			_draw_water()
			_draw_village_flames()


func _draw_surfaces() -> void:
	draw_rect(Rect2(Vector2.ZERO, map.SIZE), MEADOW)
	if map == Puzzle:
		_patch(Vector2(322, 282), Vector2(106, 31), Color("#b1c66a"))
		_patch(Vector2(516, 83), Vector2(88, 40), Color("#a1c660"))
		_patch(Vector2(532, 293), Vector2(83, 41), Color("#85b352"))
	elif map != Map:
		_patch(Vector2(688, 79), Vector2(112, 66), Color("#9ec35c"))
		_patch(map.DRY_CENTER, Vector2(106, 50), Color("#b1c66a"))
		_patch(Vector2(706, 186), Vector2(122, 39), Color("#85b352"))
		_patch(Vector2(431, 468), Vector2(74, 35), Color("#a1c660"))
	else:
		_draw_hameau_prairies()
	for wood: Array in map.WOODS:
		draw_colored_polygon(PackedVector2Array(wood), WOOD_FLOOR)
	if map != Map:
		for clearing: Array in map.BARE:
			draw_colored_polygon(PackedVector2Array(clearing), Color("#bd9b62"))
	draw_colored_polygon(PackedVector2Array(map.CLEARING), CLEARING)
	var road := PackedVector2Array(map.ROAD)
	draw_polyline(road, Color("#b89758"), map.ROAD_WIDTH)
	draw_polyline(road, Color("#e3c484"), 6.0)
	_draw_village_paths()
	_river_band(-1, 1, 6.0, Color("#6e9250"))
	_river_band(-1, 1, 3.0, Color("#d4bf79"))
	_river_band(-1, 1, 0.0, Color("#49b4c1"))
	_river_band(-0.80, 0.83, 0.0, Color("#339cba"))
	_river_band(-0.53, 0.62, 0.0, RIVER)


func _draw_hameau_prairies() -> void:
	# Les taches restent larges et espacées pour laisser respirer la prairie.
	for patch: Array in [
		[Vector2(105, 142), Vector2(93, 43), Color("#9ec35c")],
		[map.DRY_CENTER, Vector2(87, 39), Color("#b1c66a")],
		[Vector2(323, 59), Vector2(118, 49), Color("#a1c660")],
		[Vector2(311, 316), Vector2(124, 39), Color("#85b352")],
		[Vector2(548, 277), Vector2(76, 38), Color("#a4c567")],
	]:
		_patch(patch[0], patch[1], patch[2])


func _draw_village_paths() -> void:
	var paths := [
		[Vector2(241, 174), Vector2(240, 182), Vector2(244, 188)],
		[Vector2(306, 182), Vector2(304, 193), Vector2(306, 203)],
		[Vector2(295, 239), Vector2(312, 242), Vector2(320, 230), Vector2(318, 206), Vector2(320, 201)],
	] if map == Map else [
		[Vector2(758, 259), Vector2(762, 274), Vector2(782, 278)],
		[Vector2(830, 289), Vector2(839, 298)],
		[Vector2(737, 352), Vector2(753, 358), Vector2(777, 337)],
		[Vector2(826, 383), Vector2(823, 390)],
	]
	if map == Puzzle:
		paths = [
			[Vector2(562, 186), Vector2(563, 195)],
			[Vector2(504, 245), Vector2(522, 232), Vector2(528, 190)],
		]
	for path: Array in paths:
		draw_polyline(PackedVector2Array(path), Color("#e3c484"), 4.0)


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
	draw_colored_polygon(map.river_outline(left, right, margin), color)


func _draw_details() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 814
	var detail_count := 960 if map == Map or map == Puzzle else 1920
	for i in detail_count:
		var p := Vector2(rng.randi_range(0, int(map.SIZE.x) - 1), rng.randi_range(0, int(map.SIZE.y) - 1))
		var terrain: StringName = map.terrain_at(p)
		if terrain == Map.WATER:
			continue
		if terrain == Map.VILLAGE:
			_rect(p, 2, 1, Color("#bd995e"))
		elif terrain == Map.DIRT:
			_rect(p, 3, 1, Color("#ad8d61"))
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
	var reeds := [83, 99, 108, 125, 151, 201, 230, 258, 293, 324, 345] if map == Map else [
		149, 164, 187, 210, 244, 269, 291, 323, 354, 381, 404, 427]
	if map == Puzzle:
		reeds = [120, 134, 159, 175, 197, 214, 235, 243]
	for y: int in reeds:
		var side := -1.0 if y % 2 == 0 else 1.0
		var x := roundf(map.river_center(y) + side * (map.river_half_width(y) + 3.0))
		_rect(Vector2(x - 2, y + 1), 6, 2, Color("#729453"))
		_rect(Vector2(x - 1, y - 3), 1, 5, Color("#547748"))
		_rect(Vector2(x + 1, y - 5), 1, 6, Color("#557d47"))
		_rect(Vector2(x + 3, y - 2), 1, 4, Color("#7e9747"))
		_rect(Vector2(x + 1, y - 6), 1, 2, Color("#ad824d"))
	var rocks := [Vector2(145, 121), Vector2(177, 265), Vector2(378, 120),
			Vector2(354, 304), Vector2(515, 41), Vector2(555, 258), Vector2(500, 318)] if map == Map else [
			Vector2(477, 75), Vector2(512, 96), Vector2(528, 55), Vector2(548, 64),
			Vector2(661, 316), Vector2(647, 320), Vector2(674, 306), Vector2(575, 426),
			Vector2(579, 436), Vector2(611, 429), Vector2(626, 447), Vector2(595, 463)]
	if map == Puzzle:
		rocks = [Vector2(289, 42), Vector2(334, 40), Vector2(353, 25), Vector2(302, 329),
			Vector2(337, 321), Vector2(349, 340), Vector2(379, 171), Vector2(410, 183),
			Vector2(424, 161), Vector2(432, 286), Vector2(524, 258)]
	for p: Vector2 in rocks:
		_rect(p + Vector2(-1, 3), 11, 3, Color("#709c4b"))
		_rect(p, 8, 5, Color("#7e8675"))
		_rect(p + Vector2(1, -1), 5, 3, Color("#b6bd9f"))
		_rect(p + Vector2(5, 3), 3, 2, Color("#626f63"))


func _draw_objects() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 178
	for y in range(0, int(map.SIZE.y), 11):
		for x in range(0, int(map.SIZE.x), 12):
			var point := Vector2(x + rng.randi_range(-4, 4), y + rng.randi_range(-4, 4))
			if map.terrain_at(point) == Map.FOREST and rng.randf() > 0.14:
				_tree(point, rng.randi_range(5, 8), rng.randf() > 0.43)
	var shift := Vector2.ZERO if map == Map else Vector2(518, 86)
	if map == Puzzle:
		shift = Vector2(300, -10)
	for x in range(224, 265, 5):
		_rect(Vector2(x, 222) + shift, 5, 2, Color("#a27c46"))
		_rect(Vector2(x, 220) + shift, 2, 5, Color("#eed294"))
	var shrubs := [Vector2(222, 214), Vector2(262, 214), Vector2(338, 221), Vector2(348, 218)] if map == Map else [
		Vector2(742, 291), Vector2(805, 323), Vector2(838, 327), Vector2(785, 364)]
	if map == Puzzle:
		shrubs = [Vector2(480, 158), Vector2(536, 169), Vector2(549, 214), Vector2(519, 217)]
	for p: Vector2 in shrubs:
		_tree(p, 4, true)
	for i in map.HOUSE_ORIGINS.size():
		if _house_stages[i] < 4:
			_house(map.HOUSE_ORIGINS[i], HOUSES[i][0], HOUSES[i][1])
		if _house_stages[i] > 0:
			_house_damage(map.HOUSE_ORIGINS[i], _house_stages[i], i, HOUSES[i][0])
	for p: Vector2 in [Vector2(263, 177), Vector2(266, 179), Vector2(322, 232)]:
		_rect(p + shift, 4, 4, Color("#8a664c"))
		_rect(p + shift + Vector2(1, 0), 2, 2, Color("#d0a363"))


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


func _house_damage(p: Vector2, stage: int, index: int, roof: Color) -> void:
	var ash := Color("#493b36")
	var char := Color("#63473a")
	var stone := Color("#ad8968")
	var offset := Vector2(index * 3, 0)
	if stage < 4:
		_rect(p + offset + Vector2(4, 4), 7, 2, char)
		_rect(p + offset + Vector2(5, 6), 4, 3, ash)
		_rect(p + Vector2(19, 11), 4, 2, char)
		if stage >= 2:
			_rect(p + offset + Vector2(3, 7), 9, 5, ash)
			_rect(p + Vector2(2, 15), 7, 5, char)
			_rect(p + Vector2(3, 19), 10, 2, ash)
			_rect(p + Vector2(1, 22), 4, 2, stone)
		if stage >= 3:
			_rect(p + Vector2(8, 3), 12, 11, ash)
			_rect(p + Vector2(10, 4), 8, 8, Color("#272a28"))
			for x in [11, 15]:
				_rect(p + Vector2(x, 3), 2, 11, Color("#90604b"))
			_rect(p + Vector2(21, 15), 3, 6, char)
	else:
		_rect(p + Vector2(0, 4), 26, 18, Color("#a07c55"))
		_rect(p + Vector2(3, 6), 21, 13, ash)
		_rect(p + Vector2(2, 3), 3, 17, char)
		_rect(p + Vector2(2, 3), 3, 10, stone)
		_rect(p + Vector2(4, 3), 12, 2, stone)
		_rect(p + Vector2(20, 14), 4, 8, stone)
		_rect(p + Vector2(10, 18), 13, 3, char)
		_rect(p + Vector2(5, 9), 7, 4, roof.darkened(0.35))
		_rect(p + Vector2(16, 12), 6, 3, roof.darkened(0.42))
		draw_line(p + Vector2(6, 17), p + Vector2(18, 7), Color("#835742"), 2.0)
		_rect(p + Vector2(15, 15), 2, 1, Color("#dd864e"))
		_rect(p + Vector2(10, 7), 1, 1, Color("#c77d4b"))
	if stage >= 2:
		_rect(p + Vector2(23, 23), 3, 2, char)
		_rect(p + Vector2(26, 19), 2, 2, stone)
		_rect(p + Vector2(18, 20), 4, 1, stone)
	if stage >= 3:
		var smoke := p + offset + Vector2(10, 2)
		_rect(smoke, 4, 3, Color(0.41, 0.37, 0.34, 0.65))
		_rect(smoke + Vector2(1, -4), 6, 3, Color(0.53, 0.49, 0.44, 0.50))
		_rect(smoke + Vector2(4, -9), 7, 3, Color(0.66, 0.61, 0.55, 0.32))


func _draw_village_flames() -> void:
	var frame := floori(_water_time * 10.0)
	for i in _house_stages.size():
		var stage := _house_stages[i]
		if stage == 0:
			continue
		var count := 1 if stage == 4 else stage
		for j in count:
			var p: Vector2 = map.HOUSE_ORIGINS[i] + Vector2(4 + (i * 7 + j * 9) % 18, 7 + (i + j * 3) % 7)
			var flicker := (frame + i * 3 + j * 2) % 5
			var height := 3 + flicker % 3 + (stage if stage < 4 else 0)
			var bend := flicker % 3 - 1
			_rect(p - Vector2(2, 1), 5, 2, Color("#8f382a"))
			_rect(p + Vector2(bend, -height + 1), 2, height, Color("#e45b32"))
			_rect(p + Vector2(-1, -height + 3), 3, height - 2, Color("#ff9c43"))
			_rect(p - Vector2(0, 2), 1, 2, Color("#ffe495"))
			if flicker == 2:
				_rect(p + Vector2(2, -height - 2), 1, 1, Color("#ffd675"))
		var smoke: Vector2 = map.HOUSE_ORIGINS[i] + Vector2(9 + i * 2, 1)
		for j in (1 if stage == 1 else 3):
			var drift := (frame + j * 4 + i * 2) % 12
			_rect(smoke + Vector2(drift / 3, -drift), 2 + j, 2,
					Color(0.62, 0.56, 0.49, 0.40 * (1.0 - drift / 12.0)))


func _draw_water() -> void:
	var frame := floorf(_water_time * 10.0) / 10.0
	for i in 43:
		var y: float = map.RIVER_SOURCE_Y + fposmod(i * 37.0 + frame * 6.0, map.RIVER_END_Y - map.RIVER_SOURCE_Y)
		var across := sin(i * 2.76) * 0.72
		var p := Vector2(map.river_center(y) + across * map.river_half_width(y), y).round()
		var width := mini(3 + i % 6, floori(map.river_half_width(y) * (1.0 - across)))
		if width <= 0:
			continue
		var alpha := (0.5 + 0.5 * sin(i * 1.6 + frame * TAU / 4.0)) * 0.40
		_rect(p, width, 1, Color(0.68, 0.96, 0.93, alpha))


func _rect(p: Vector2, width: int, height: int, color: Color) -> void:
	draw_rect(Rect2(p, Vector2(width, height)), color)
