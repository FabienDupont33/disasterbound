extends RefCounted

const Hameau = preload("res://resources/maps/le_hameau.gd")
const SIZE := Vector2(640, 360)
const HOUSE_SIZE := Vector2(26, 22)
const RIVER_SOURCE_Y := 105
const RIVER_END_Y := 255
const ROAD_WIDTH := 10.0
const DRY_CENTER := Vector2(324, 282)
const HOUSE_ORIGINS := [Vector2(485, 123), Vector2(550, 165), Vector2(491, 224)]
const CLEARING := [
	Vector2(477, 119), Vector2(506, 116), Vector2(531, 136), Vector2(572, 147),
	Vector2(593, 174), Vector2(584, 208), Vector2(544, 231), Vector2(520, 251),
	Vector2(483, 253), Vector2(470, 225), Vector2(480, 199), Vector2(466, 173),
	Vector2(453, 150),
]
const WOODS := [
	[Vector2(0, 85), Vector2(39, 68), Vector2(87, 75), Vector2(111, 61),
	Vector2(155, 73), Vector2(187, 59), Vector2(219, 76), Vector2(243, 71),
	Vector2(279, 82), Vector2(317, 84), Vector2(346, 72), Vector2(380, 76),
	Vector2(407, 95), Vector2(430, 93), Vector2(462, 109), Vector2(464, 126),
	Vector2(420, 138), Vector2(388, 128), Vector2(349, 119), Vector2(326, 105),
	Vector2(284, 122), Vector2(258, 153), Vector2(243, 194), Vector2(223, 213),
	Vector2(246, 239), Vector2(228, 272), Vector2(197, 287), Vector2(178, 271),
	Vector2(129, 284), Vector2(118, 260), Vector2(82, 271), Vector2(55, 251),
	Vector2(0, 263)],
	[Vector2(369, 260), Vector2(410, 253), Vector2(436, 218), Vector2(465, 218),
	Vector2(478, 242), Vector2(462, 260), Vector2(471, 283), Vector2(436, 301),
	Vector2(404, 288), Vector2(379, 298)],
]
const BARE := [
	[Vector2(268,0), Vector2(378,0), Vector2(384,32), Vector2(368,47), Vector2(336,58),
	Vector2(310,52), Vector2(284,64), Vector2(265,46)],
	[Vector2(267,360), Vector2(260,334), Vector2(284,313), Vector2(320,312),
	Vector2(342,300), Vector2(365,318), Vector2(378,360)],
	[Vector2(350,156), Vector2(375,140), Vector2(404,151), Vector2(424,147),
	Vector2(438,167), Vector2(433,194), Vector2(405,212), Vector2(370,203)],
]
const ROAD := [Vector2(633, 199), Vector2(600, 187), Vector2(563, 195),
	Vector2(528, 190), Vector2(507, 175), Vector2(502, 144)]


static var _water := river_outline(-1, 1)
static var _bank := river_outline(-1, 1, 3)
static var _village := PackedVector2Array(CLEARING)
static var _woods := _polygons(WOODS)
static var _bare := _polygons(BARE)


static func _polygons(source: Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for polygon: Array in source:
		result.append(PackedVector2Array(polygon))
	return result


static func river_center(y: float) -> float:
	return 307.0 + sin((y - 90.0) / 34.0) * 23.0


static func _taper(y: float) -> float:
	var edge := 1.0 - clampf(minf(y - RIVER_SOURCE_Y, RIVER_END_Y - y) / 25.0, 0.0, 1.0)
	return sqrt(1.0 - edge * edge)


static func river_half_width(y: float) -> float:
	return (24.0 + 4.0 * sin(y / 33.0)) * _taper(y)


static func river_outline(left: float, right: float, margin: float = 0.0) -> PackedVector2Array:
	var result := PackedVector2Array()
	for y in range(RIVER_SOURCE_Y, RIVER_END_Y + 1, 3):
		result.append(Vector2(roundf(river_center(y) + left * river_half_width(y) - margin * _taper(y)), y))
	for y in range(RIVER_END_Y - 3, RIVER_SOURCE_Y, -3):
		result.append(Vector2(roundf(river_center(y) + right * river_half_width(y) + margin * _taper(y)), y))
	return result


static func is_water(point: Vector2) -> bool:
	return _near_river(point) and Geometry2D.is_point_in_polygon(point, _water)


static func _near_river(point: Vector2) -> bool:
	return point.y >= RIVER_SOURCE_Y and point.y <= RIVER_END_Y and absf(point.x - river_center(point.y)) <= 34.0


static func distance_to_water(point: Vector2) -> float:
	if is_water(point):
		return 0.0
	var distance := INF
	for i in _water.size():
		var edge := Geometry2D.get_closest_point_to_segment(point, _water[i], _water[(i + 1) % _water.size()])
		distance = minf(distance, point.distance_squared_to(edge))
	return sqrt(distance)


static func terrain_at(point: Vector2) -> StringName:
	if is_water(point):
		return Hameau.WATER
	if Geometry2D.is_point_in_polygon(point, _village):
		return Hameau.VILLAGE
	for polygon in _bare:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return Hameau.DIRT
	for polygon in _woods:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return Hameau.FOREST
	return Hameau.MEADOW


static func fire_terrain_at(point: Vector2) -> StringName:
	var terrain := terrain_at(point)
	if terrain != Hameau.MEADOW:
		return terrain
	if _near_river(point) and Geometry2D.is_point_in_polygon(point, _bank):
		return Hameau.DIRT
	if point.x >= 492 and point.y >= 145:
		for i in range(1, ROAD.size()):
			var nearest := Geometry2D.get_closest_point_to_segment(point, ROAD[i - 1], ROAD[i])
			if point.distance_squared_to(nearest) <= pow(ROAD_WIDTH * 0.5 + 0.5, 2):
				return Hameau.DIRT
	if ((point - DRY_CENTER) / Vector2(100, 33)).length_squared() < 1.0:
		return Hameau.DRY_GRASS
	return Hameau.MEADOW
