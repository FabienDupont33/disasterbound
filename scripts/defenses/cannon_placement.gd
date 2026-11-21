extends RefCounted

const Map = preload("res://resources/maps/le_hameau.gd")
const Simulation = preload("res://scripts/fire/fire_simulation.gd")
const Cannon = preload("res://scripts/defenses/water_cannon.gd")
const FOOTPRINT := 7.0


static func allowed(point: Vector2, simulation: Simulation, cannons: Array[Cannon] = [], map: Script = Map) -> bool:
	var margin := Vector2.ONE * FOOTPRINT
	var map_bounds := Rect2(Vector2.ZERO, map.SIZE)
	if not map_bounds.has_point(point - margin) or not map_bounds.has_point(point + margin):
		return false
	for origin: Vector2 in map.HOUSE_ORIGINS:
		if Rect2(origin, map.HOUSE_SIZE).grow(FOOTPRINT).has_point(point):
			return false
	for cannon in cannons:
		var offset := (point - cannon.position).abs()
		if offset.x < FOOTPRINT * 2.0 and offset.y < FOOTPRINT * 2.0:
			return false
	var cells := simulation.cells_near(point, FOOTPRINT)
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			if simulation.state[y * simulation.grid.x + x] == Simulation.Burn.BURNING:
				return false
	for y in [-FOOTPRINT, 0.0, FOOTPRINT]:
		for x in [-FOOTPRINT, 0.0, FOOTPRINT]:
			if map.is_water(point + Vector2(x, y)):
				return false
	return true
