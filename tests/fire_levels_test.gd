extends SceneTree

const Levels = preload("res://resources/maps/fire_levels.gd")
const Simulation = preload("res://scripts/fire/fire_simulation.gd")
const FireConfig = preload("res://resources/balance/fire_configuration.gd")
const Attempt = preload("res://scripts/objectives/fire_attempt.gd")
const Rules = preload("res://resources/balance/attempt_configuration.gd")
const Placement = preload("res://scripts/defenses/cannon_placement.gd")
const Cannon = preload("res://scripts/defenses/water_cannon.gd")
const CannonConfig = preload("res://resources/balance/water_cannon_configuration.gd")

var _failed := false


func _initialize() -> void:
	var path := "user://fire_levels_test_%d.cfg" % OS.get_process_id()
	var first := _simulate_clear(Levels.FIRST, path)
	var second := _simulate_clear(Levels.SECOND, path)
	_check(second == roundi(first * 1.75), "Récompenses comparables : multiplicateur du niveau 2")
	_check(Attempt.Progression.new(path).hameau_completed, "La victoire au Hameau déverrouille durablement le niveau 2")
	_check_edge_exit(path)
	_check_initial_resistance()
	DirAccess.remove_absolute(path)
	quit(1 if _failed else 0)


func _simulate_clear(id: StringName, path: String) -> int:
	var level: Dictionary = Levels.LEVELS[id]
	var map: Script = level.map
	var fire := FireConfig.new()
	var starts: Array[Vector2] = [fire.initial_position]
	if id == Levels.SECOND:
		starts.assign(level.starts)
		fire.wind_direction = level.wind
		fire.wind_strength = level.strength
		fire.initial_radius = level.radius
		fire.initial_intensity = level.intensity
	var simulation := Simulation.new()
	simulation.setup(map.SIZE, Callable(map, "fire_terrain_at"), fire)
	var settings := Rules.new()
	settings.level_reward_multiplier = level.reward
	var attempt := Attempt.new(settings, [], path)
	attempt.level_id = id
	if id == Levels.FIRST:
		_check(not attempt.progression.hameau_completed, "Le niveau 2 est verrouillé sur un profil neuf")
	else:
		_check(simulation.grid.x * simulation.grid.y == 18360, "La vallée comporte 18 360 cellules")
		var river := Vector2(map.river_center(145), 145)
		_check(not Placement.allowed(river, simulation, [], map), "La nouvelle rivière interdit le placement")
		_check(not Placement.allowed(map.HOUSE_ORIGINS[0], simulation, [], map), "Les nouvelles maisons bloquent le placement")
		_check(not simulation.ignite(river), "La nouvelle eau ne brûle pas")
		_check(Placement.allowed(Vector2(692, 185), simulation, [], map), "Placement au-delà des anciennes limites")
	for point in starts:
		simulation.ignite_area(point, fire.initial_radius, fire.initial_intensity)
		_check(simulation.intensity[simulation.index_at(point)] > 0.0, "Allumage au point annoncé %s" % point)
	_check(simulation.burning_count > starts.size() * 3, "Chaque foyer contient plusieurs cellules")
	attempt.observe_ignition(simulation)
	for i in starts.size():
		simulation.water_area(starts[i], fire.initial_radius + 1.0, 4.0)
		attempt.step(simulation, 0.1)
		if i < starts.size() - 1:
			_check(attempt.outcome == Attempt.Outcome.PENDING, "Le second foyer empêche la victoire prématurée")
	_check(attempt.outcome == Attempt.Outcome.VICTORY, "Victoire après extinction globale")
	return attempt.awarded_points


func _check_edge_exit(path: String) -> void:
	var simulation := Simulation.new()
	var config := FireConfig.new()
	simulation.setup(Vector2(100, 100), func(_point): return &"forest", config)
	var edge := Vector2(2.5, 12.5)
	var interior := Vector2(57.5, 62.5)
	simulation.ignite(edge)
	simulation.ignite(interior)
	var attempt := Attempt.new(Rules.new(), [], path)
	simulation.step()
	attempt.step(simulation, 0.1)
	_check(simulation.exited_map and simulation.burning_count == 2, "La sortie laisse les foyers intérieurs actifs")
	simulation.water_area(edge, 1.0, 5.0)
	attempt.step(simulation, 0.1)
	_check(attempt.outcome == Attempt.Outcome.PENDING, "Aucune victoire avec un foyer encore actif")
	simulation.water_area(interior, 1.0, 5.0)
	attempt.step(simulation, 0.1)
	_check(attempt.outcome == Attempt.Outcome.VICTORY, "Victoire après extinction du dernier foyer intérieur")
	simulation.reset()
	_check(not simulation.exited_map, "L'indicateur de sortie est réinitialisé")


func _check_initial_resistance() -> void:
	var map = Levels.VALLEY
	var level: Dictionary = Levels.LEVELS[Levels.SECOND]
	var config := FireConfig.new()
	config.wind_direction = level.wind
	config.wind_strength = level.strength
	var simulation := Simulation.new()
	simulation.setup(map.SIZE, Callable(map, "fire_terrain_at"), config)
	for point: Vector2 in level.starts:
		simulation.ignite_area(point, level.radius, level.intensity)
	var initial := simulation.burning_count
	var minimum := 1.0
	var maximum := 0.0
	for intensity in simulation.intensity:
		if intensity > 0.0:
			minimum = minf(minimum, intensity)
			maximum = maxf(maximum, intensity)
	_check(initial > 180 and maximum - minimum > 0.2, "Foyers établis et intensités variées")
	var gun_config := CannonConfig.new()
	var cannons: Array[Cannon] = []
	for point: Vector2 in [Vector2(185, 144), Vector2(267, 144), Vector2(267, 400), Vector2(348, 400)]:
		cannons.append(Cannon.new(gun_config, point, gun_config.efficiency_at_distance(map.distance_to_water(point))))
	for i in 20:
		for cannon in cannons:
			cannon.step(simulation, 0.1)
		simulation.step()
	_check(simulation.burning_count > 0 and cannons.any(func(cannon): return cannon.spraying),
			"Quatre canons autour des foyers ne les éteignent pas en deux secondes")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK ", message)
	else:
		_failed = true
		push_error(message)
