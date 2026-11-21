extends RefCounted

const HAMEAU = preload("res://resources/maps/le_hameau.gd")
const VALLEY = preload("res://resources/maps/la_vallee_des_pins.gd")
const PUZZLE = preload("res://resources/maps/fire_puzzle.gd")
const EconomyConfig = preload("res://resources/balance/economy_configuration.gd")
const FIRST := &"hameau"
const SECOND := &"deux_fronts"
const EXPERIMENT := &"fire_puzzle"
const LEVELS := {
	FIRST: {"name": "Le Hameau", "map": HAMEAU, "reward": 1.0,
		"wind": Vector2(1, 0.55), "strength": 0.52},
	SECOND: {"name": "La Vallée des Pins", "map": VALLEY, "reward": 1.75,
		"starts": [Vector2(226, 109), Vector2(307, 359)], "wind": Vector2(1, 0.12),
		"strength": 0.56, "radius": 29.0, "intensity": 0.92},
	EXPERIMENT: {"name": "Les Deux Passages", "map": PUZZLE, "reward": 0.0,
		"starts": [Vector2(142, 174)], "wind": Vector2(1, 0.08),
		"strength": 0.57, "radius": 29.0, "intensity": 0.91, "seed": 408,
		"base_income": 0.75, "territory_income": 2.5},
}


static func economy_for(id: StringName, base: EconomyConfig) -> EconomyConfig:
	var level: Dictionary = LEVELS[id]
	if not level.has("base_income"):
		return base
	var settings: EconomyConfig = base.duplicate()
	settings.base_income = level.base_income
	settings.territory_income = level.territory_income
	return settings
