extends RefCounted

const SIZE := Vector2(640, 360)
const MEADOW := &"meadow"
const FOREST := &"forest"
const WATER := &"water"
const VILLAGE := &"village"
const DIRT := &"dirt"
const DRY_GRASS := &"dry_grass"
const ROAD_WIDTH := 10.0
# Correspond à la nuance chaude au sud-ouest du hameau.
const DRY_CENTER := Vector2(155, 251)
const DRY_RADIUS := Vector2(60, 22)

const NORTH_WOOD := [
	Vector2(0, 0), Vector2(214, 0), Vector2(210, 20), Vector2(199, 28),
	Vector2(204, 45), Vector2(190, 62), Vector2(174, 61), Vector2(159, 82),
	Vector2(131, 86), Vector2(116, 77), Vector2(96, 104), Vector2(71, 112),
	Vector2(49, 103), Vector2(30, 117), Vector2(0, 109),
]
const SOUTH_WOOD := [
	Vector2(0, 284), Vector2(27, 273), Vector2(49, 278), Vector2(68, 263),
	Vector2(91, 269), Vector2(101, 287), Vector2(128, 289), Vector2(150, 308),
	Vector2(145, 325), Vector2(166, 343), Vector2(171, 360), Vector2(0, 360),
]
const EAST_WOOD := [
	Vector2(640, 34), Vector2(640, 242), Vector2(618, 236), Vector2(604, 216),
	Vector2(586, 218), Vector2(567, 205), Vector2(574, 188), Vector2(549, 172),
	Vector2(541, 147), Vector2(554, 130), Vector2(551, 108), Vector2(573, 98),
	Vector2(577, 77), Vector2(601, 70), Vector2(610, 48),
]
const CLEARING := [
	Vector2(195, 156), Vector2(219, 137), Vector2(252, 143), Vector2(273, 126),
	Vector2(302, 128), Vector2(320, 141), Vector2(351, 147), Vector2(368, 169),
	Vector2(363, 192), Vector2(376, 213), Vector2(361, 239), Vector2(333, 246),
	Vector2(313, 263), Vector2(284, 257), Vector2(269, 243), Vector2(229, 240),
	Vector2(204, 225), Vector2(207, 204), Vector2(185, 184),
]
const WOODS := [NORTH_WOOD, SOUTH_WOOD, EAST_WOOD]
const ROAD := [
	Vector2(-8, 210), Vector2(38, 201), Vector2(83, 208), Vector2(123, 202),
	Vector2(163, 185), Vector2(203, 179), Vector2(244, 188), Vector2(277, 200),
	Vector2(306, 203), Vector2(332, 198), Vector2(349, 182), Vector2(356, 166),
]

static var _clearing_polygon := PackedVector2Array(CLEARING)
static var _wood_polygons: Array[PackedVector2Array] = [
	PackedVector2Array(NORTH_WOOD), PackedVector2Array(SOUTH_WOOD), PackedVector2Array(EAST_WOOD),
]


static func river_center(y: float) -> float:
	return 458.0 + sin(y / 49.0 + 0.65) * 35.0 + sin(y / 24.0) * 8.0


static func river_half_width(y: float) -> float:
	return 26.0 + cos(y / 37.0 + 1.1) * 5.0


static func terrain_at(point: Vector2) -> StringName:
	if absf(point.x - river_center(point.y)) <= river_half_width(point.y):
		return WATER
	if Geometry2D.is_point_in_polygon(point, _clearing_polygon):
		return VILLAGE
	for wood in _wood_polygons:
		if Geometry2D.is_point_in_polygon(point, wood):
			return FOREST
	return MEADOW


static func fire_terrain_at(point: Vector2) -> StringName:
	var terrain := terrain_at(point)
	if terrain != MEADOW:
		return terrain
	var bank_distance := absf(point.x - river_center(point.y)) - river_half_width(point.y)
	if bank_distance <= 4.0:
		return DIRT
	if point.y >= 160.0 and point.y <= 216.0 and point.x <= 362.0:
		for i in range(1, ROAD.size()):
			var nearest := Geometry2D.get_closest_point_to_segment(point, ROAD[i - 1], ROAD[i])
			if point.distance_squared_to(nearest) <= pow(ROAD_WIDTH * 0.5 + 0.5, 2):
				return DIRT
	if ((point - DRY_CENTER) / DRY_RADIUS).length_squared() < 1.0:
		return DRY_GRASS
	return MEADOW
