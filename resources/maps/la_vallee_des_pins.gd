extends RefCounted

const Hameau = preload("res://resources/maps/le_hameau.gd")
const SIZE := Vector2(900, 510)
const HOUSE_SIZE := Vector2(26, 22)
const RIVER_SOURCE_Y := 135
const RIVER_END_Y := 447
const ROAD_WIDTH := 10.0
const DRY_CENTER := Vector2(664, 432)
const HOUSE_ORIGINS := [Vector2(746, 238), Vector2(817, 267), Vector2(724, 331), Vector2(813, 362)]
const CLEARING := [
	Vector2(712,260), Vector2(730,230), Vector2(771,218), Vector2(797,245),
	Vector2(844,250), Vector2(865,275), Vector2(849,318), Vector2(858,350),
	Vector2(847,394), Vector2(804,403), Vector2(769,377), Vector2(713,367),
	Vector2(703,342), Vector2(724,311), Vector2(715,289),
]
const WOODS := [
	[Vector2(0,0), Vector2(387,0), Vector2(409,40), Vector2(389,73), Vector2(420,108),
	Vector2(394,138), Vector2(405,170), Vector2(374,187), Vector2(382,219),
	Vector2(352,249), Vector2(362,284), Vector2(422,311), Vector2(434,347),
	Vector2(404,380), Vector2(429,413), Vector2(402,445), Vector2(367,439),
	Vector2(350,476), Vector2(317,482), Vector2(296,510), Vector2(0,510)],
	[Vector2(591,152), Vector2(616,138), Vector2(648,148), Vector2(667,175), Vector2(654,203),
	Vector2(681,228), Vector2(674,246), Vector2(640,252), Vector2(616,226), Vector2(588,216),
	Vector2(568,187)],
	[Vector2(900,12), Vector2(900,153), Vector2(866,141), Vector2(843,122), Vector2(840,92),
	Vector2(809,61), Vector2(819,39), Vector2(854,34), Vector2(865,11)],
]
const ROAD := [Vector2(892,410), Vector2(856,397), Vector2(823,390), Vector2(794,369),
	Vector2(777,337), Vector2(769,305), Vector2(782,278), Vector2(815,285), Vector2(850,303)]
const BARE := [
	[Vector2(445,0), Vector2(572,0), Vector2(576,35), Vector2(557,58), Vector2(567,78),
	Vector2(551,106), Vector2(525,107), Vector2(509,96), Vector2(478,112), Vector2(460,98),
	Vector2(466,71), Vector2(441,49)],
	[Vector2(540,399), Vector2(567,391), Vector2(591,400), Vector2(609,389), Vector2(632,402),
	Vector2(643,425), Vector2(625,453), Vector2(636,467), Vector2(612,480), Vector2(583,472),
	Vector2(567,452), Vector2(543,441), Vector2(529,419)],
	[Vector2(638,299), Vector2(669,289), Vector2(693,308), Vector2(682,326), Vector2(649,338), Vector2(627,321)],
]

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
	return 518.0 + sin((y - 110.0) / 51.0) * 24.0 + sin(y / 104.0) * 10.0


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
	if point.x >= 760 and point.y >= 267:
		for i in range(1, ROAD.size()):
			var nearest := Geometry2D.get_closest_point_to_segment(point, ROAD[i - 1], ROAD[i])
			if point.distance_squared_to(nearest) <= pow(ROAD_WIDTH * 0.5 + 0.5, 2):
				return Hameau.DIRT
	if ((point - DRY_CENTER) / Vector2(73, 40)).length_squared() < 1.0:
		return Hameau.DRY_GRASS
	return Hameau.MEADOW
