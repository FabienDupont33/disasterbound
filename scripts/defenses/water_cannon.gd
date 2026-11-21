extends RefCounted

const Simulation = preload("res://scripts/fire/fire_simulation.gd")
const Configuration = preload("res://resources/balance/water_cannon_configuration.gd")

var config: Configuration
var position: Vector2
var hp: float
var efficiency: float
var angle := -PI / 2.0
var impact: Vector2
var spraying := false
var _target := -1


func _init(settings: Configuration, location: Vector2, hydraulic_efficiency: float) -> void:
	config = settings
	position = location
	efficiency = hydraulic_efficiency
	hp = config.max_hp


func step(simulation: Simulation, dt: float) -> void:
	spraying = false
	if hp <= 0.0:
		return
	_apply_heat_damage(simulation, dt)
	if hp <= 0.0:
		return
	if _target < 0 or simulation.state[_target] != Simulation.Burn.BURNING:
		_target = _find_target(simulation)
	if _target < 0:
		return
	impact = simulation.cell_center(_target)
	var desired := (impact - position).angle()
	angle = rotate_toward(angle, desired, config.rotation_speed * dt)
	if absf(angle_difference(angle, desired)) <= 0.07:
		spraying = true
		var dose := config.flow_per_second * config.extinguishing_power * efficiency * dt
		simulation.water_area(impact, config.splash_radius, dose, true)


func _find_target(simulation: Simulation) -> int:
	var best := -1
	var best_distance := config.range_px * config.range_px
	var cells := simulation.cells_near(position, config.range_px)
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			var index := y * simulation.grid.x + x
			if simulation.state[index] != Simulation.Burn.BURNING:
				continue
			var distance := position.distance_squared_to(simulation.cell_center(index))
			if distance <= best_distance:
				best_distance = distance
				best = index
	return best


func _apply_heat_damage(simulation: Simulation, dt: float) -> void:
	var exposure := 0.0
	var cells := simulation.cells_near(position, config.exposure_radius)
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			var index := y * simulation.grid.x + x
			var distance := position.distance_to(simulation.cell_center(index))
			exposure += simulation.intensity[index] * maxf(0.0, 1.0 - distance / config.exposure_radius)
	var fraction := clampf(exposure / (2.5 * simulation.config.max_intensity), 0.0, 1.0)
	hp = maxf(0.0, hp - fraction * config.heat_damage_per_second * dt)
