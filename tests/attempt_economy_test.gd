extends SceneTree

const Economy = preload("res://scripts/core/attempt_economy.gd")
const EconomyConfig = preload("res://resources/balance/economy_configuration.gd")
const Map = preload("res://resources/maps/fire_puzzle.gd")
const Levels = preload("res://resources/maps/fire_levels.gd")
const Sim = preload("res://scripts/fire/fire_simulation.gd")
const FireConfig = preload("res://resources/balance/fire_configuration.gd")
const Cannon = preload("res://scripts/defenses/water_cannon.gd")
const CannonConfig = preload("res://resources/balance/water_cannon_configuration.gd")
const Placement = preload("res://scripts/defenses/cannon_placement.gd")
const Attempt = preload("res://scripts/objectives/fire_attempt.gd")
const Rules = preload("res://resources/balance/attempt_configuration.gd")

var _failed := false


func _initialize() -> void:
	var economy := Economy.new()
	var settings := EconomyConfig.new()
	economy.configure(settings)
	_check(economy.credits == 100 and economy.price == 100 and economy.spend(), "Premier canon à 100 crédits")
	_check(economy.credits == 0 and not economy.spend(), "Le double achat est refusé")
	economy.configure(settings, 10, 0, 0, false)
	_check(economy.credits == 0 and economy.price == 90, "Réévaluer les bonus ne restaure pas les crédits dépensés")
	economy.configure(settings, 10, 15, 25)
	_check(economy.credits == 125 and economy.price == 90 and economy.spend() and not economy.can_buy(),
			"Les bonus économiques laissent un seul achat au départ")
	economy.configure(settings)
	economy.advance(1.0, 0.0)
	var healthy := economy.income
	economy.advance(1.0, 0.5)
	_check(is_equal_approx(healthy, 6.5) and is_equal_approx(economy.income, 4.0),
			"Le revenu diminue avec la perte permanente de végétation")
	var experiment := Levels.economy_for(Levels.EXPERIMENT, settings)
	economy.configure(experiment)
	_check(economy.credits == 100 and economy.price == 100 and is_equal_approx(economy.income, 3.25),
			"Le prototype conserve son premier achat et gagne 50 % de revenu en moins")
	for id: StringName in [Levels.FIRST, Levels.SECOND]:
		economy.configure(Levels.economy_for(id, settings))
		_check(is_equal_approx(economy.income, 6.5), "Revenu de campagne inchangé : %s" % id)
	var old_ticks := _ticks_to_buy(settings)
	var new_ticks := _ticks_to_buy(experiment)
	_check(old_ticks == 154 and new_ticks == 308, "Deuxième canon à terrain intact : 15,4 s puis 30,8 s")
	for label: String in ["A", "B", "C", "D", "Village concentré", "Canon seul"]:
		print(label, " · ", _run(label))
	quit(1 if _failed else 0)


func _ticks_to_buy(settings: EconomyConfig) -> int:
	var economy := Economy.new()
	economy.configure(settings)
	economy.spend()
	for tick in range(1, 501):
		economy.advance(0.1, 0.0)
		if economy.can_buy():
			return tick
	return -1


func _run(label: String) -> Dictionary:
	var level: Dictionary = Levels.LEVELS[Levels.EXPERIMENT]
	var fire := FireConfig.new()
	fire.wind_direction = level.wind
	fire.wind_strength = level.strength
	fire.seed = level.seed
	var simulation := Sim.new()
	simulation.setup(Map.SIZE, Map.fire_terrain_at, fire)
	var houses: Array[Rect2] = []
	for origin: Vector2 in Map.HOUSE_ORIGINS:
		houses.append(Rect2(origin, Map.HOUSE_SIZE))
	var attempt := Attempt.new(Rules.new(), houses, "user://economy_test_%d.cfg" % OS.get_process_id())
	attempt.awards_progress = false
	var economy := Economy.new()
	economy.configure(Levels.economy_for(Levels.EXPERIMENT, EconomyConfig.new()))
	var cannon_config := CannonConfig.new()
	var first: Vector2 = {
		"A": Vector2(177, 198), "B": Vector2(462, 118), "C": Vector2(325, 83),
		"D": Vector2(325, 83), "Village concentré": Vector2(462, 118), "Canon seul": Vector2(325, 83),
	}[label]
	var positions := [first, Vector2(345, 274), Vector2(370, 115)] if label != "Canon seul" else [first]
	if label == "Village concentré":
		positions = [first, Vector2(455, 199), Vector2(535, 268)]
	var cannons: Array[Cannon] = []
	var second := -1.0
	var dt := 1.0 / fire.tick_rate
	for point: Vector2 in level.starts:
		simulation.ignite_area(point, level.radius, level.intensity)
	for tick in 2400:
		if cannons.size() < positions.size() and economy.can_buy() and (label != "D" or tick >= 120):
			var point: Vector2 = positions[cannons.size()]
			if Placement.allowed(point, simulation, cannons, Map):
				economy.spend()
				cannons.append(Cannon.new(cannon_config, point, cannon_config.efficiency_at_distance(Map.distance_to_water(point))))
				if cannons.size() == 2:
					second = attempt.elapsed
		for cannon in cannons:
			cannon.step(simulation, dt)
		simulation.step()
		attempt.step(simulation, dt)
		if attempt.outcome != Attempt.Outcome.PENDING:
			break
		economy.advance(dt, simulation.burned_fraction())
	return {"issue": attempt.outcome, "PV": snappedf(attempt.hp, 0.1), "second": snappedf(second, 0.1),
		"durée": snappedf(attempt.elapsed, 0.1), "brûlé": snappedf(simulation.burned_fraction() * 100, 0.1),
		"revenu_final": snappedf(economy.income, 0.01), "achats": cannons.size()}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK ", message)
	else:
		_failed = true
		push_error(message)
