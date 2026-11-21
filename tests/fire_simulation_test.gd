extends SceneTree

const Simulation = preload("res://scripts/fire/fire_simulation.gd")
const Configuration = preload("res://resources/balance/fire_configuration.gd")
const Map = preload("res://resources/maps/le_hameau.gd")

var _failed := false


func _initialize() -> void:
	var settings := Configuration.new()
	var simulation := Simulation.new()
	simulation.setup(Map.SIZE, Map.fire_terrain_at, settings)
	_check(simulation.ignite(settings.initial_position), "Allumage en forêt")
	for point: Vector2 in [Vector2(8, 208), Vector2(250, 185), Vector2(Map.river_center(120), 120)]:
		_check(not simulation.ignite(point), "Allumage bloqué à %s" % point)
	for i in 1700:
		simulation.step()
	var meadow_burned := false
	var east_wood_burned := false
	for y in simulation.grid.y:
		for x in simulation.grid.x:
			var i := y * simulation.grid.x + x
			if simulation.state[i] != Simulation.Burn.INTACT:
				meadow_burned = meadow_burned or simulation.terrain[i] == Map.MEADOW
				east_wood_burned = east_wood_burned or (
					x * Simulation.CELL_SIZE >= 545 and simulation.terrain[i] == Map.FOREST)
				if not settings.terrain_profiles.has(StringName(simulation.terrain[i])):
					_check(false, "Propagation sur terrain ininflammable")
	_check(meadow_burned, "Propagation de la forêt vers la prairie")
	_check(east_wood_burned, "La propagation atteint la forêt est en contournant la source")
	_check(simulation.state[simulation.index_at(settings.initial_position)] == Simulation.Burn.CHARRED,
			"Épuisement et carbonisation")
	_check(not simulation.ignite(settings.initial_position), "Réallumage impossible sans combustible")
	simulation.reset()
	_check(simulation.burning_count == 0 and simulation.ignite(settings.initial_position), "Remise à zéro")

	var east := _burned_downwind(Vector2.RIGHT)
	var west := _burned_downwind(Vector2.LEFT)
	_check(east > west, "Le changement de vent modifie la propagation vers l'est")

	var barrier := Simulation.new()
	barrier.setup(Vector2(155, 35), _barrier_terrain, settings)
	barrier.ignite(Vector2(55, 15))
	barrier.ignite(Vector2(5, 15))
	for i in 320:
		barrier.step()
	_check(barrier.state[barrier.index_at(Vector2(30, 15))] == Simulation.Burn.CHARRED, "Fusion des foyers")
	_check(barrier.state[barrier.index_at(Vector2(95, 15))] == Simulation.Burn.INTACT, "Terre infranchissable")
	_check(barrier.burning_count == 0, "Extinction naturelle complète")
	_check(_single_cell_duration(Map.DRY_GRASS) < _single_cell_duration(Map.MEADOW),
			"L'herbe sèche se consume avant la prairie")
	_check(_single_cell_duration(Map.MEADOW) < _single_cell_duration(Map.FOREST),
			"La prairie se consume avant la forêt")
	quit(1 if _failed else 0)


func _burned_downwind(direction: Vector2) -> int:
	var settings := Configuration.new()
	settings.wind_direction = direction
	settings.wind_strength = 0.85
	var simulation := Simulation.new()
	simulation.setup(Vector2(105, 55), func(_point): return Map.FOREST, settings)
	simulation.ignite(Vector2(52, 27))
	for i in 65:
		simulation.step()
	var count := 0
	for y in simulation.grid.y:
		for x in range(13, simulation.grid.x):
			if simulation.state[y * simulation.grid.x + x] != Simulation.Burn.INTACT:
				count += 1
	return count


func _barrier_terrain(point: Vector2) -> StringName:
	return Map.DIRT if point.x >= 75 and point.x < 85 else Map.MEADOW


func _single_cell_duration(terrain: StringName) -> int:
	var simulation := Simulation.new()
	simulation.setup(Vector2(5, 5), func(_point): return terrain, Configuration.new())
	simulation.ignite(Vector2(2, 2))
	for i in 300:
		simulation.step()
		if simulation.burning_count == 0:
			return i + 1
	return 300


func _check(condition: bool, description: String) -> void:
	if condition:
		print("OK ", description)
	else:
		_failed = true
		push_error(description)
