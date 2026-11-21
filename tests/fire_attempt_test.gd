extends SceneTree

const Attempt = preload("res://scripts/objectives/fire_attempt.gd")
const Rules = preload("res://resources/balance/attempt_configuration.gd")
const Simulation = preload("res://scripts/fire/fire_simulation.gd")
const FireConfig = preload("res://resources/balance/fire_configuration.gd")
const Cannon = preload("res://scripts/defenses/water_cannon.gd")
const CannonConfig = preload("res://resources/balance/water_cannon_configuration.gd")
const Map = preload("res://resources/maps/le_hameau.gd")

var _failed := false


func _initialize() -> void:
	var path := "user://attempt_test_%d.cfg" % OS.get_process_id()
	var houses: Array[Rect2] = []
	for origin: Vector2 in Map.HOUSE_ORIGINS:
		houses.append(Rect2(origin, Map.HOUSE_SIZE))
	var rules := Rules.new()
	var attempt := Attempt.new(rules, houses, path)
	var simulation := Simulation.new()
	var fire := FireConfig.new()
	simulation.setup(Map.SIZE, Map.fire_terrain_at, fire)
	var dt := 1.0 / fire.tick_rate
	attempt.step(simulation, dt)
	_check(attempt.outcome == Attempt.Outcome.PENDING, "Aucune victoire avant l'allumage")
	simulation.ignite_initial_area()
	_check(simulation.burning_count > 1, "Foyer d'origine étendu")
	attempt.step(simulation, dt)
	_check(attempt.hp == rules.village_max_hp, "Le foyer distant ne touche pas le village")
	var staggered_damage := false
	var first_damage := 0.0
	for tick in 1600:
		simulation.step()
		var before := attempt.hp
		attempt.step(simulation, dt)
		if before < rules.village_max_hp or attempt.hp < before:
			if first_damage == 0.0:
				first_damage = before - attempt.hp
			staggered_damage = staggered_damage or attempt.house_damage_stage(0) != attempt.house_damage_stage(2)
		if attempt.outcome != Attempt.Outcome.PENDING:
			break
	print("Sans canon : résultat %d, %.1f s, %.1f PV, %.1f %% brûlé" % [
		attempt.outcome, attempt.elapsed, attempt.hp, simulation.burned_fraction() * 100.0,
	])
	_check(attempt.outcome == Attempt.Outcome.DEFEAT and attempt.hp == 0.0, "Défaite possible sans défense")
	_check(first_damage > 0.0 and first_damage < 2.0, "Premier contact progressif")
	_check(staggered_damage and attempt.house_damage_stage(0) == 4
			and attempt.house_damage_stage(2) == 4, "Dégradation décalée puis ruines")
	var defeat_points := attempt.awarded_points
	_check(defeat_points > 0, "Une défaite rapporte des points")
	attempt.step(simulation, dt)
	_check(attempt.total_points == defeat_points, "Un seul crédit pour le même bilan")
	attempt.reset()
	simulation.reset()
	_check(attempt.hp == rules.village_max_hp and attempt.awarded_points == 0
			and simulation.burned_fraction() == 0.0 and attempt.house_damage_stage(0) == 0,
			"Réinitialisation des données et des maisons")
	simulation.ignite_initial_area()
	attempt.observe_ignition(simulation)
	var cannons: Array[Cannon] = []
	for position: Vector2 in [Vector2(93, 115), Vector2(109, 111), Vector2(127, 114)]:
		cannons.append(Cannon.new(CannonConfig.new(), position, 0.65))
	for tick in 180:
		for cannon in cannons:
			cannon.step(simulation, dt)
		simulation.step()
		attempt.step(simulation, dt)
		if attempt.outcome != Attempt.Outcome.PENDING:
			break
	print("Trois canons avancés : résultat %d, %.1f s, %.1f PV, %.1f %% brûlé" % [
		attempt.outcome, attempt.elapsed, attempt.hp, simulation.burned_fraction() * 100.0,
	])
	_check(attempt.outcome == Attempt.Outcome.VICTORY and simulation.burning_count == 0
			and attempt.elapsed >= 0.3, "Victoire après extinction réelle du foyer étendu")
	_check(attempt.awarded_points > defeat_points, "Une victoire bien préservée rapporte davantage")
	_check(attempt.save_error == OK and Attempt.new(rules, houses, path).total_points == attempt.total_points,
			"Les deux bilans sont conservés dans la sauvegarde incendie")
	_check(_victory_points_after_burning(5, attempt, fire) > _victory_points_after_burning(100, attempt, fire),
			"À victoire égale, une meilleure préservation rapporte davantage")
	DirAccess.remove_absolute(path)
	_test_territory(fire)
	quit(1 if _failed else 0)


func _victory_points_after_burning(ticks: int, attempt: Attempt, fire: FireConfig) -> int:
	attempt.reset()
	var simulation := Simulation.new()
	simulation.setup(Vector2(5, 5), func(_point): return Map.FOREST, fire)
	var point := Vector2(2.5, 2.5)
	simulation.ignite(point)
	attempt.observe_ignition(simulation)
	for tick in ticks:
		simulation.step()
	simulation.water_area(point, 2.0, 2.0)
	attempt.step(simulation, 1.0 / fire.tick_rate)
	return attempt.awarded_points


func _test_territory(fire: FireConfig) -> void:
	var simulation := Simulation.new()
	simulation.setup(Vector2(10, 5), func(point: Vector2): return Map.FOREST if point.x < 5 else Map.WATER, fire)
	var point := Vector2(2.5, 2.5)
	simulation.ignite(point)
	for tick in 5:
		simulation.step()
	var burned := simulation.burned_fraction()
	_check(burned > 0.0 and burned < 1.0, "La végétation partiellement brûlée contribue au bilan")
	simulation.water_area(point, 2.0, 2.0)
	_check(simulation.burning_count == 0 and simulation.burned_fraction() == burned,
			"L'extinction ne restaure pas le territoire")
	simulation.ignite(point)
	for tick in 300:
		simulation.step()
	_check(is_equal_approx(simulation.burned_fraction(), 1.0), "L'eau est exclue du territoire inflammable")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("OK ", description)
	else:
		_failed = true
		push_error(description)
