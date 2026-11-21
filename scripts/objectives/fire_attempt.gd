extends RefCounted

const Simulation = preload("res://scripts/fire/fire_simulation.gd")
const Configuration = preload("res://resources/balance/attempt_configuration.gd")
const Progression = preload("res://scripts/progression/fire_progression.gd")
enum Outcome { PENDING, VICTORY, DEFEAT }

var config: Configuration
var hp := 0.0
var elapsed := 0.0
var exposed := false
var outcome := Outcome.PENDING
var awarded_points := 0
var progression: Progression
var level_id: StringName
var awards_progress := true
var total_points: int:
	get: return progression.points
var save_error: Error:
	get: return progression.save_error
var _saw_fire := false
var _houses: Array[Rect2] = []
var _house_heat := PackedFloat32Array()
var _house_stages := PackedByteArray()
var _exposure_grid := Vector2i.ZERO
var _exposure_cells := PackedInt32Array()
var _cell_owners := PackedInt32Array()
var _cell_contact := PackedFloat32Array()


func _init(settings: Configuration, houses: Array[Rect2], path: String = Progression.SAVE_PATH) -> void:
	config = settings
	_houses = houses
	progression = Progression.new(path)
	reset()


func reset() -> void:
	hp = config.village_max_hp
	elapsed = 0.0
	exposed = false
	outcome = Outcome.PENDING
	awarded_points = 0
	_saw_fire = false
	_house_heat.resize(_houses.size())
	_house_heat.fill(0.0)
	_house_stages.resize(_houses.size())
	_house_stages.fill(0)


func use_level(id: StringName, houses: Array[Rect2]) -> void:
	level_id = id
	_houses = houses
	_exposure_grid = Vector2i.ZERO


func _prepare_exposure(simulation: Simulation) -> void:
	_exposure_grid = simulation.grid
	_exposure_cells.clear()
	_cell_owners.clear()
	_cell_contact.clear()
	if config.damage_radius <= 0.0:
		return
	for i in simulation.fuel.size():
		var center := simulation.cell_center(i)
		var nearest := -1
		var distance := config.damage_radius
		for house_index in _houses.size():
			var house := _houses[house_index]
			var gap := center.distance_to(center.clamp(house.position, house.end))
			if gap < distance:
				distance = gap
				nearest = house_index
		if nearest >= 0:
			_exposure_cells.append(i)
			_cell_owners.append(nearest)
			_cell_contact.append(1.0 - distance / config.damage_radius)


func observe_ignition(simulation: Simulation) -> void:
	_saw_fire = _saw_fire or simulation.burning_count > 0


func step(simulation: Simulation, interval: float) -> void:
	if outcome != Outcome.PENDING:
		return
	observe_ignition(simulation)
	elapsed += interval
	var exposure := _exposure(simulation, interval)
	exposed = exposure > 0.0
	hp = maxf(0.0, hp - exposure * config.damage_per_second * interval)
	if exposed:
		_update_house_stages()
	if hp <= 0.0:
		_finish(Outcome.DEFEAT, simulation.burned_fraction())
	elif _saw_fire and simulation.burning_count == 0:
		# Le scénario n'a pas de foyers programmés. Sans combustion, il n'y a plus de transfert.
		_finish(Outcome.VICTORY, simulation.burned_fraction())


func house_damage_stage(index: int) -> int:
	return _house_stages[index]


func _update_house_stages() -> void:
	if hp <= 0.0:
		_house_stages.fill(4)
		return
	var remaining := hp / config.village_max_hp
	if remaining > 0.75:
		return
	var total_heat := 0.0
	for dose in _house_heat:
		total_heat += dose
	var mean_heat := total_heat / maxf(1.0, _house_heat.size())
	for i in _house_heat.size():
		var delay := clampf((mean_heat - _house_heat[i]) / maxf(1.0, elapsed), 0.0, 0.08)
		var stage := clampi(floori((1.0 - remaining - delay) * 4.0), 0, 3)
		_house_stages[i] = maxi(_house_stages[i], stage)


func _exposure(simulation: Simulation, interval: float) -> float:
	if simulation.burning_count == 0:
		return 0.0
	if _exposure_grid != simulation.grid:
		_prepare_exposure(simulation)
	var peaks := PackedFloat32Array()
	peaks.resize(_houses.size())
	for slot in _exposure_cells.size():
		var house := _cell_owners[slot]
		var intensity := simulation.intensity[_exposure_cells[slot]] / simulation.config.max_intensity
		peaks[house] = maxf(peaks[house], intensity * _cell_contact[slot])
	var peak := 0.0
	var total := 0.0
	for i in peaks.size():
		_house_heat[i] += peaks[i] * interval
		peak = maxf(peak, peaks[i])
		total += peaks[i]
	return peak + (total - peak) * config.additional_house_weight


func _finish(result: Outcome, burned: float) -> void:
	outcome = result
	if not awards_progress:
		return
	var bonus := roundi((1.0 - burned) * config.preservation_bonus)
	if result == Outcome.VICTORY:
		awarded_points = config.victory_base_points + bonus
	else:
		var survival := floori(elapsed / maxf(0.1, config.seconds_per_survival_point))
		awarded_points = config.defeat_base_points + mini(config.defeat_survival_cap, survival) + bonus
	awarded_points = roundi(awarded_points * maxf(0.0, config.level_reward_multiplier))
	progression.credit(awarded_points, level_id if result == Outcome.VICTORY else &"")
