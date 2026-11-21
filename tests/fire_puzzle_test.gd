extends SceneTree

const Levels = preload("res://resources/maps/fire_levels.gd")
const Map = preload("res://resources/maps/fire_puzzle.gd")
const Simulation = preload("res://scripts/fire/fire_simulation.gd")
const FireConfig = preload("res://resources/balance/fire_configuration.gd")
const Attempt = preload("res://scripts/objectives/fire_attempt.gd")
const AttemptConfig = preload("res://resources/balance/attempt_configuration.gd")
const Cannon = preload("res://scripts/defenses/water_cannon.gd")
const CannonConfig = preload("res://resources/balance/water_cannon_configuration.gd")
const Placement = preload("res://scripts/defenses/cannon_placement.gd")

const SCENARIOS := {
	"A · Sans canon": [],
	"B · Foyer": [Vector2(105, 141), Vector2(152, 128), Vector2(177, 198)],
	"C · Village": [Vector2(462, 118), Vector2(455, 199), Vector2(535, 268)],
	"D · Passage nord": [Vector2(306, 79), Vector2(337, 82), Vector2(368, 93)],
	"E · Répartie": [Vector2(325, 83), Vector2(370, 115), Vector2(345, 274)],
	"F · Interception": [Vector2(304, 89), Vector2(354, 110), Vector2(323, 265)],
}

var _failed := false
var _path := "user://fire_puzzle_test_%d.cfg" % OS.get_process_id()


func _initialize() -> void:
	var outcomes: Array[Dictionary] = []
	for label: String in SCENARIOS:
		var result := _run(SCENARIOS[label])
		outcomes.append(result)
		print(label, " · ", result)
	_check(outcomes[0].outcome == Attempt.Outcome.DEFEAT and outcomes[0].arrival > 0.0,
			"Le feu atteint et détruit le village sans défense")
	_check(outcomes[1].duration > 2.0, "Trois canons au foyer ne terminent pas la partie instantanément")
	_check(outcomes[3].outcome == Attempt.Outcome.DEFEAT, "Se concentrer sur le nord laisse une menace")
	_check(outcomes[3].south > 0.0 and outcomes[3].north < 0.0,
			"Le feu contourne les canons du nord par le sud")
	_check(outcomes[5].outcome == Attempt.Outcome.VICTORY, "Trois canons de base sauvent le village")
	_check(_run(SCENARIOS["F · Interception"]) == outcomes[5], "Résultat reproductible")
	_check(not FileAccess.file_exists(_path), "Les essais n'écrivent aucune progression")
	quit(1 if _failed else 0)


func _run(positions: Array) -> Dictionary:
	var level: Dictionary = Levels.LEVELS[Levels.EXPERIMENT]
	var configuration := FireConfig.new()
	configuration.wind_direction = level.wind
	configuration.wind_strength = level.strength
	configuration.seed = level.seed
	var simulation := Simulation.new()
	simulation.setup(Map.SIZE, Map.fire_terrain_at, configuration)
	var houses: Array[Rect2] = []
	for origin: Vector2 in Map.HOUSE_ORIGINS:
		houses.append(Rect2(origin, Map.HOUSE_SIZE))
	var attempt := Attempt.new(AttemptConfig.new(), houses, _path)
	attempt.awards_progress = false
	attempt.level_id = Levels.EXPERIMENT
	var cannon_config := CannonConfig.new()
	var cannons: Array[Cannon] = []
	for point: Vector2 in positions:
		_check(Placement.allowed(point, simulation, cannons, Map), "Placement valide %s" % point)
		cannons.append(Cannon.new(cannon_config, point, cannon_config.efficiency_at_distance(Map.distance_to_water(point))))
	for start: Vector2 in level.starts:
		simulation.ignite_area(start, level.radius, level.intensity)
	var arrival := -1.0
	var north := -1.0
	var south := -1.0
	var dt := 1.0 / configuration.tick_rate
	for tick in 3200:
		for cannon in cannons:
			cannon.step(simulation, dt)
		simulation.step()
		attempt.step(simulation, dt)
		if north < 0.0 and _crossed(simulation, 50, 140):
			north = attempt.elapsed
		if south < 0.0 and _crossed(simulation, 246, 315):
			south = attempt.elapsed
		if arrival < 0.0 and attempt.exposed:
			arrival = attempt.elapsed
		if attempt.outcome != Attempt.Outcome.PENDING:
			break
	return {
		"outcome": attempt.outcome, "hp": snappedf(attempt.hp, 0.1), "duration": snappedf(attempt.elapsed, 0.1),
		"burned": snappedf(simulation.burned_fraction() * 100.0, 0.1), "arrival": snappedf(arrival, 0.1),
		"destroyed": cannons.filter(func(cannon): return cannon.hp <= 0.0).size(),
		"north": snappedf(north, 0.1), "south": snappedf(south, 0.1),
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK ", message)
	else:
		_failed = true
		push_error(message)


func _crossed(simulation: Simulation, from_y: int, to_y: int) -> bool:
	for y in range(from_y, to_y, Simulation.CELL_SIZE):
		if simulation.state[simulation.index_at(Vector2(385, y))] != Simulation.Burn.INTACT:
			return true
	return false
