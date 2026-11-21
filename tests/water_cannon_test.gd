extends SceneTree

const Map = preload("res://resources/maps/le_hameau.gd")
const Simulation = preload("res://scripts/fire/fire_simulation.gd")
const FireConfig = preload("res://resources/balance/fire_configuration.gd")
const Cannon = preload("res://scripts/defenses/water_cannon.gd")
const Config = preload("res://resources/balance/water_cannon_configuration.gd")
const Placement = preload("res://scripts/defenses/cannon_placement.gd")

var _failed := false


func _initialize() -> void:
	var fire := FireConfig.new()
	var simulation := Simulation.new()
	simulation.setup(Map.SIZE, Map.fire_terrain_at, fire)
	simulation.ignite(fire.initial_position)
	var location := Vector2(140, 110)
	var river := Vector2(Map.river_center(120), 120)
	_check(Placement.allowed(location, simulation), "Placement sur terrain stable")
	_check(not Placement.allowed(river, simulation), "Placement interdit dans la rivière")
	_check(not Placement.allowed(Map.HOUSE_ORIGINS[0], simulation), "Placement interdit sur une maison")
	_check(not Placement.allowed(fire.initial_position, simulation), "Placement interdit dans les flammes")
	_check(not Placement.allowed(Vector2(4, 40), simulation), "Emprise entière dans la carte")
	var config := Config.new()
	var near_bank := river + Vector2(-48, 0)
	var near_efficiency := config.efficiency_at_distance(Map.distance_to_water(near_bank))
	var far_efficiency := config.efficiency_at_distance(Map.distance_to_water(location))
	_check(near_efficiency > far_efficiency and far_efficiency > 0.0, "Rendement lié à la rive")

	var cannon := Cannon.new(config, location, far_efficiency)
	var seed := simulation.index_at(fire.initial_position)
	var neighbor := simulation.index_at(simulation.cell_center(seed) + Vector2(5, 0))
	var original_fuel := simulation.fuel[seed]
	var sprayed := false
	var peak_dampness := 0.0
	for tick in 32:
		_tick(simulation, cannon)
		sprayed = sprayed or cannon.spraying
		peak_dampness = maxf(peak_dampness, simulation.dampness_at(neighbor))
	_check(sprayed and absf(cannon.angle + PI / 2.0) > 0.1, "Acquisition, rotation et tir automatiques")
	_check(simulation.burning_count == 0 and not cannon.spraying, "Extinction du foyer et arrêt du jet")
	_check(simulation.state[seed] == Simulation.Burn.INTACT and simulation.fuel[seed] > original_fuel * 0.8,
			"Combustible conservé après extinction")
	_check(peak_dampness > 0.0 and simulation.dampness_at(neighbor) < peak_dampness,
			"Arrosage de la zone voisine et séchage progressif")
	_check(_ignition_delay(true) > _ignition_delay(false), "L'humidité retarde la réinflammation")
	_check(_medium_fire(false) > _medium_fire(true), "Le canon réduit la propagation d'un feu moyen")

	simulation.reset()
	cannon = Cannon.new(config, Vector2(120, 56), far_efficiency)
	for y in range(42, 73, 5):
		for x in range(107, 139, 5):
			simulation.ignite(Vector2(x, y))
	for tick in 70:
		_tick(simulation, cannon)
	_check(cannon.hp == 0.0 and not cannon.spraying and simulation.burning_count > 0,
			"Un incendie intense détruit le canon et le jet s'arrête")
	_compare_placements()
	_check_water_response()
	quit(1 if _failed else 0)


func _check_water_response() -> void:
	var forest_one := _intensity_after_water(Map.FOREST, 1)
	var forest_two := _intensity_after_water(Map.FOREST, 2)
	var forest_four := _intensity_after_water(Map.FOREST, 4)
	var grass_one := _intensity_after_water(Map.MEADOW, 1)
	_check(forest_one > grass_one, "La forêt établie résiste davantage que la prairie")
	_check(forest_one > forest_two and forest_two > forest_four and forest_four > 0.0,
			"Les quatre jets coopèrent sans éteindre instantanément le foyer")
	_check(forest_two - forest_four < 2.0 * (forest_one - forest_two), "Rendements décroissants sur une même cellule")


func _intensity_after_water(terrain: StringName, shots: int) -> float:
	var fire := FireConfig.new()
	var simulation := Simulation.new()
	simulation.setup(Vector2(5, 5), func(_point): return terrain, fire)
	var point := Vector2(2.5, 2.5)
	simulation.ignite(point, 0.78)
	for i in shots:
		simulation.water_area(point, 2.0, 0.25, true)
	simulation.step()
	return simulation.intensity[0]


func _compare_placements() -> void:
	var concentrated := _strategy("Concentrée", [Vector2(225, 134), Vector2(277, 116), Vector2(338, 134)])
	var advanced := _strategy("Avancée", [Vector2(140, 110), Vector2(565, 110), Vector2(99, 244)])
	var hydraulic := _strategy("Hydraulique", [Vector2(388, 107), Vector2(382, 190), Vector2(505, 240)])
	_check(advanced.x < concentrated.x, "La défense avancée préserve plus de terrain dans cet essai")
	_check(hydraulic.y > advanced.y and hydraulic.y > concentrated.y, "La rive améliore le rendement moyen")
	_check(hydraulic.x != advanced.x, "Le rendement et la couverture entraînent des résultats différents")


func _strategy(label: String, positions: Array[Vector2]) -> Vector2i:
	var fire := FireConfig.new()
	var simulation := Simulation.new()
	simulation.setup(Map.SIZE, Map.fire_terrain_at, fire)
	var config := Config.new()
	var cannons: Array[Cannon] = []
	var efficiency_sum := 0.0
	for point in positions:
		_check(Placement.allowed(point, simulation, cannons), "%s : placement %s" % [label, point])
		var efficiency := config.efficiency_at_distance(Map.distance_to_water(point))
		cannons.append(Cannon.new(config, point, efficiency))
		efficiency_sum += efficiency
	for point: Vector2 in [fire.initial_position, Vector2(587, 154), Vector2(393, 121)]:
		simulation.ignite(point)
	for tick in 450:
		for cannon in cannons:
			cannon.step(simulation, 1.0 / fire.tick_rate)
		simulation.step()
	var charred := simulation.state.count(Simulation.Burn.CHARRED)
	var average := roundi(100.0 * efficiency_sum / cannons.size())
	print("%s : %d cellules carbonisées, rendement moyen %d %%" % [label, charred, average])
	return Vector2i(charred, average)


func _medium_fire(with_cannon: bool) -> int:
	var fire := FireConfig.new()
	var simulation := Simulation.new()
	simulation.setup(Map.SIZE, Map.fire_terrain_at, fire)
	for point: Vector2 in [Vector2(106, 56), Vector2(116, 56), Vector2(106, 66), Vector2(116, 66)]:
		simulation.ignite(point)
	var cannon: Cannon
	if with_cannon:
		var config := Config.new()
		var location := Vector2(140, 110)
		cannon = Cannon.new(config, location, config.efficiency_at_distance(Map.distance_to_water(location)))
	for tick in 50:
		_tick(simulation, cannon)
	return simulation.burning_count


func _ignition_delay(wet: bool) -> int:
	var simulation := Simulation.new()
	simulation.setup(Vector2(10, 5), func(_point): return Map.FOREST, FireConfig.new())
	var target := Vector2(7.5, 2.5)
	if wet:
		simulation.water_area(target, 4.0, 2.2)
	simulation.ignite(Vector2(2.5, 2.5))
	for tick in 150:
		simulation.step()
		if simulation.state[simulation.index_at(target)] == Simulation.Burn.BURNING:
			return tick
	return 150


func _tick(simulation: Simulation, cannon: Cannon) -> void:
	if cannon != null:
		cannon.step(simulation, 1.0 / simulation.config.tick_rate)
	simulation.step()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("OK ", description)
	else:
		_failed = true
		push_error(description)
