extends SceneTree

const Progression = preload("res://scripts/progression/fire_progression.gd")
const Technologies = preload("res://resources/balance/fire_technologies.gd")
const Cannon = preload("res://scripts/defenses/water_cannon.gd")
const CannonConfig = preload("res://resources/balance/water_cannon_configuration.gd")
const AttemptConfig = preload("res://resources/balance/attempt_configuration.gd")
const Simulation = preload("res://scripts/fire/fire_simulation.gd")
const FireConfig = preload("res://resources/balance/fire_configuration.gd")

var _failed := false


func _initialize() -> void:
	var path := "user://technology_test_%d.cfg" % OS.get_process_id()
	var old := ConfigFile.new()
	old.set_value("fire", "technology_points", 800)
	old.save(path)
	var progression := Progression.new(path)
	_check(progression.points == 800 and progression.level(&"range") == 0, "Sauvegarde de points compatible")
	_check(Technologies.cost(&"range", 2) == 79 and Technologies.cost(&"rotation", 0) == 121,
			"Croissance par niveau et profondeur")
	_check(not progression.purchase(&"cannon_four", 0), "Les points seuls ne débloquent pas le quatrième canon")
	_check(progression.purchase(&"power", 0) and progression.points == 770, "Achat débité immédiatement")
	_check(not progression.purchase(&"power", 0) and progression.points == 770, "Réémission ignorée")
	_check(progression.purchase(&"power", 1), "Deuxième niveau de puissance")
	for id: StringName in [&"range", &"cadence", &"armor", &"village"]:
		_check(progression.purchase(id, 0), "Achat indépendant : %s" % id)
	_check(progression.purchase(&"range", 1) and progression.purchase(&"rotation", 0),
			"Un premier niveau ouvre la rotation")
	var base := CannonConfig.new()
	var effective := progression.effective_cannon(base)
	_check(is_equal_approx(effective.range_px, 130.0) and is_equal_approx(effective.max_hp, 55.2)
			and is_equal_approx(effective.rotation_speed, 6.71), "Les bonus de cadence et de rotation s'additionnent")
	_check(is_equal_approx(effective.extinguishing_power, 2.275)
			and progression.effective_attempt(AttemptConfig.new()).village_max_hp == 120.0,
			"Puissance et PV du village effectifs")
	_check(base.range_px == 100.0 and progression.effective_cannon(base).range_px == effective.range_px,
			"Base intacte, bonus appliqué une seule fois")
	_check(_shot_intensity(base, 90.0) > _shot_intensity(effective, 90.0), "Deux niveaux de puissance sur le feu")
	_check(_shot_intensity(base, 120.0) > _shot_intensity(effective, 120.0), "Deux niveaux de portée sur le ciblage")
	progression.credit(5500)
	_check(progression.purchase(&"logistics", 0) and not progression.purchase(&"cannon_four", 0),
			"Le déploiement exige explicitement 3/3 en puissance")
	_check(progression.purchase(&"power", 2) and not progression.purchase(&"power", 3), "Plafond de statistique 3/3")
	_check(progression.purchase(&"cannon_four", 0) and progression.bonus(&"discount") == 10, "Achats groupés")
	_check(not progression.purchase(&"cannon_five", 0), "Le cinquième exige un investissement supplémentaire")
	for level in 3:
		_check(progression.purchase(&"pressure", level), "Réserve de pression")
	_check(progression.purchase(&"cannon_five", 0) and progression.bonus(&"income") == 15, "Réseau de collecte")
	for level in 3:
		_check(progression.purchase(&"reserve", level), "Équipe de réserve")
	_check(progression.purchase(&"cannon_six", 0) and progression.bonus(&"startup") == 25, "Fonds de départ")
	var restored := Progression.new(path)
	_check(restored.points == progression.points and restored.level(&"power") == 3 and restored.bonus(&"startup") == 25,
			"Solde, niveaux et nœuds majeurs restaurés")
	restored.credit(12)
	_check(Progression.new(path).level(&"cannon_six") == 1, "Une récompense préserve les nœuds")
	DirAccess.remove_absolute(path)
	_check(not Progression.new(path).purchase(&"range", 0), "Achat refusé sans points")
	_check_migration(path)
	var unreadable := FileAccess.open(path, FileAccess.WRITE)
	unreadable.store_string("[broken\nversion = 1")
	unreadable.close()
	var corrupt := Progression.new(path)
	corrupt.credit(50)
	_check(corrupt.save_error != OK and FileAccess.get_file_as_string(path) == "[broken\nversion = 1",
			"Une erreur de lecture bloque l'écrasement")
	DirAccess.remove_absolute(path)
	quit(1 if _failed else 0)


func _check_migration(path: String) -> void:
	var legacy := ConfigFile.new()
	legacy.set_value("fire", "technology_points", 80)
	legacy.set_value("fire_technologies", "range", 5)
	legacy.set_value("fire_technologies", "deployment", 3)
	legacy.save(path)
	var migration := Progression.new(path)
	_check(migration.migrated and migration.refunded_points == 770 and migration.points == 850
			and migration.level(&"range") == 3 and migration.bonus(&"discount") == 0,
			"Migration : niveaux compatibles et remboursement aux prix historiques")
	var reopened := Progression.new(path)
	_check(not reopened.migrated and reopened.points == migration.points, "Remboursement unique et persistant")


func _shot_intensity(config: CannonConfig, distance: float) -> float:
	var simulation := Simulation.new()
	simulation.setup(Vector2(20, 160), func(_point): return &"forest", FireConfig.new())
	var target := Vector2(7.5, 12.5)
	simulation.ignite(target, 0.78)
	var cannon := Cannon.new(config, target + Vector2(0, distance), 1.0)
	cannon.step(simulation, 0.1)
	simulation.step()
	return simulation.intensity[simulation.index_at(target)]


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK ", message)
	else:
		_failed = true
		push_error(message)
