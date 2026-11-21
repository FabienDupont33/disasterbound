extends RefCounted

const Configuration = preload("res://resources/balance/fire_configuration.gd")
const CELL_SIZE := 5
const NEIGHBORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
enum Burn { INTACT, BURNING, CHARRED }

var config: Configuration
var grid: Vector2i
var terrain: Array[StringName] = []
var fuel := PackedFloat32Array()
var moisture := PackedFloat32Array()
var heat := PackedFloat32Array()
var intensity := PackedFloat32Array()
var state := PackedByteArray()
var burning_count := 0
var wet_count := 0
var exited_map := false
var _burned_area := 0.0
var _vegetation_cells := 0

var _initial_fuel := PackedFloat32Array()
var _initial_moisture := PackedFloat32Array()
var _burn_rate := PackedFloat32Array()
var _ignition_heat := PackedFloat32Array()
var _incoming := PackedFloat32Array()
var _water_total := PackedFloat32Array()
var _water_peak := PackedFloat32Array()
var _water_cells := PackedInt32Array()
var _neighbors := PackedInt32Array()
var _bounds: Rect2
var _terrain_at: Callable


func setup(size: Vector2, terrain_at: Callable, settings: Configuration) -> void:
	config = settings
	_bounds = Rect2(Vector2.ZERO, size)
	_terrain_at = terrain_at
	grid = Vector2i((size / CELL_SIZE).ceil())
	var count := grid.x * grid.y
	terrain.resize(count)
	_initial_fuel.resize(count)
	_initial_moisture.resize(count)
	_burn_rate.resize(count)
	_ignition_heat.resize(count)
	_neighbors.resize(count * NEIGHBORS.size())
	_vegetation_cells = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed
	for i in count:
		var cell := Vector2i(i % grid.x, floori(float(i) / grid.x))
		var center := cell_center(i)
		terrain[i] = terrain_at.call(center)
		var profile: Vector3 = config.terrain_profiles.get(terrain[i], Vector3.ZERO)
		_initial_fuel[i] = maxf(0.0, profile.x) * rng.randf_range(0.83, 1.17)
		if _initial_fuel[i] > 0.0:
			_vegetation_cells += 1
		_initial_moisture[i] = clampf(profile.y + rng.randf_range(-0.16, 0.16), 0.0, 1.0)
		_burn_rate[i] = profile.z
		_ignition_heat[i] = rng.randf_range(0.65, 1.35)
		for direction in NEIGHBORS.size():
			var neighbor: Vector2i = cell + NEIGHBORS[direction]
			_neighbors[i * NEIGHBORS.size() + direction] = _index(neighbor)
	reset()


func reset() -> void:
	fuel = _initial_fuel.duplicate()
	moisture = _initial_moisture.duplicate()
	heat.resize(fuel.size())
	intensity.resize(fuel.size())
	state.resize(fuel.size())
	_incoming.resize(fuel.size())
	_water_total.resize(fuel.size())
	_water_peak.resize(fuel.size())
	_water_total.fill(0.0)
	_water_peak.fill(0.0)
	_water_cells.clear()
	heat.fill(0.0)
	intensity.fill(0.0)
	state.fill(Burn.INTACT)
	burning_count = 0
	wet_count = 0
	exited_map = false
	_burned_area = 0.0


func ignite(point: Vector2, initial_fraction: float = 0.23) -> bool:
	var i := index_at(point)
	if i < 0 or fuel[i] <= 0.0 or state[i] != Burn.INTACT:
		return false
	if not config.terrain_profiles.has(_terrain_at.call(point)):
		return false
	_ignite_cell(i, initial_fraction)
	return true


func ignite_initial_area() -> void:
	ignite_area(config.initial_position, config.initial_radius, config.initial_intensity)


func ignite_area(point: Vector2, radius: float, intensity_fraction: float) -> void:
	var cells := cells_near(point, radius)
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			var center := cell_center(y * grid.x + x)
			if center.distance_to(point) <= radius:
				var position_factor := 1.0 - 0.42 * center.distance_to(point) / radius
				var variation := 0.90 + 0.15 * fposmod(x * 0.381 + y * 0.719, 1.0)
				ignite(center, minf(1.0, intensity_fraction * position_factor * variation))
	ignite(point, intensity_fraction)


func burned_fraction() -> float:
	return clampf(_burned_area / maxi(1, _vegetation_cells), 0.0, 1.0)


func index_at(point: Vector2) -> int:
	if not _bounds.has_point(point):
		return -1
	return _index(Vector2i((point / CELL_SIZE).floor()))


func _index(cell: Vector2i) -> int:
	if not Rect2i(Vector2i.ZERO, grid).has_point(cell):
		return -1
	return cell.y * grid.x + cell.x


func cell_center(index: int) -> Vector2:
	return (Vector2(index % grid.x, floori(float(index) / grid.x)) + Vector2(0.5, 0.5)) * CELL_SIZE


func cells_near(point: Vector2, radius: float) -> Rect2i:
	var extent := Vector2.ONE * radius
	var first := Vector2i(((point - extent) / CELL_SIZE).floor())
	var last := Vector2i(((point + extent) / CELL_SIZE).floor())
	return Rect2i(first, last - first + Vector2i.ONE).intersection(Rect2i(Vector2i.ZERO, grid))


func _ignite_cell(i: int, initial_fraction: float = 0.23) -> void:
	state[i] = Burn.BURNING
	intensity[i] = config.max_intensity * initial_fraction
	burning_count += 1


## Les variations sont signées. Retirer tout le combustible crée un coupe-feu local.
func adjust_cell(point: Vector2, fuel_delta: float, moisture_delta: float,
		heat_delta: float, intensity_delta: float) -> void:
	var i := index_at(point)
	if i < 0 or _initial_fuel[i] <= 0.0 or state[i] == Burn.CHARRED:
		return
	fuel[i] = clampf(fuel[i] + fuel_delta, 0.0, _initial_fuel[i])
	moisture[i] = clampf(moisture[i] + moisture_delta, 0.0, 1.0)
	heat[i] = maxf(0.0, heat[i] + heat_delta)
	if state[i] == Burn.BURNING:
		intensity[i] = clampf(intensity[i] + intensity_delta, 0.0, config.max_intensity)
		if intensity_delta < 0.0 and intensity[i] <= 0.001:
			_finish_burn(i, maxf(0.0, heat[i] + config.residual_heat - absf(heat_delta)))


func water_area(point: Vector2, radius: float, amount: float, queued: bool = false) -> void:
	if radius <= 0.0 or amount <= 0.0:
		return
	var cells := cells_near(point, radius)
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			var index := y * grid.x + x
			var distance := point.distance_to(cell_center(index))
			if distance <= radius:
				var dose := amount * lerpf(1.0, 0.45, distance / radius)
				if queued:
					if _water_total[index] <= 0.0:
						_water_cells.append(index)
					_water_total[index] += dose
					_water_peak[index] = maxf(dose, _water_peak[index])
				else:
					_apply_water(index, dose)


func _apply_water(index: int, dose: float) -> void:
	var fuel_factor := _initial_fuel[index] / maxf(0.01, config.water_fuel_reference)
	var intensity_fraction := intensity[index] / maxf(0.01, config.max_intensity)
	var resistance := 1.0 + config.water_resistance * fuel_factor * intensity_fraction
	adjust_cell(cell_center(index), 0.0, dose * 0.40, -dose, -dose / resistance)


func step() -> void:
	var dt := 1.0 / config.tick_rate
	var overlap := maxf(0.001, config.water_overlap_reference * dt)
	for index in _water_cells:
		var additional := _water_total[index] - _water_peak[index]
		var effective := _water_peak[index] + additional / (1.0 + additional / overlap)
		_apply_water(index, effective)
	var retention := exp(-config.heat_loss * dt)
	var wind := config.wind_direction.normalized() * config.wind_strength * config.wind_influence
	var weights := PackedFloat32Array()
	for direction: Vector2i in NEIGHBORS:
		weights.append(maxf(0.1, 1.0 + wind.dot(Vector2(direction))))
	# Tous les transferts utilisent les intensités du début du pas.
	_incoming.fill(0.0)
	for i in fuel.size():
		if state[i] != Burn.BURNING or fuel[i] <= 0.0:
			continue
		var amount := intensity[i] * config.propagation * dt
		for d in NEIGHBORS.size():
			var target := _neighbors[i * NEIGHBORS.size() + d]
			if target < 0:
				# La chaleur sort du domaine. Les cellules au bord poursuivent leur combustion normale.
				exited_map = exited_map or (amount > 0.0 and weights[d] > 0.0)
			elif state[target] == Burn.INTACT and fuel[target] > 0.0:
				_incoming[target] += amount * weights[d]
	wet_count = 0
	for i in fuel.size():
		if moisture[i] > _initial_moisture[i]:
			moisture[i] = move_toward(moisture[i], _initial_moisture[i], config.drying_per_second * dt)
			if moisture[i] > _initial_moisture[i] + 0.001:
				wet_count += 1
		if state[i] == Burn.BURNING:
			_burn(i, dt, _water_total[i] > 0.0)
		elif state[i] == Burn.INTACT and fuel[i] > 0.0 and (_incoming[i] > 0.0 or heat[i] > 0.0):
			var warmed := heat[i] * retention + _incoming[i]
			heat[i] = warmed if warmed >= 0.0001 else 0.0
			var threshold := _ignition_heat[i] * (0.53 + 1.7 * moisture[i])
			# La chaleur résiduelle facilite une reprise si un foyer voisin chauffe encore la cellule.
			if _incoming[i] > 0.0 and heat[i] >= threshold:
				_ignite_cell(i)
	for index in _water_cells:
		_water_total[index] = 0.0
		_water_peak[index] = 0.0
	_water_cells.clear()


func _burn(i: int, dt: float, watered: bool) -> void:
	var target := config.max_intensity * minf(1.0, fuel[i] / 0.8) * (1.0 - moisture[i] * 0.42)
	if terrain[i] == &"meadow" or terrain[i] == &"dry_grass":
		target *= config.prairie_intensity_factor
	if not watered or target < intensity[i]:
		intensity[i] = move_toward(intensity[i], target, dt * (config.growth if target > intensity[i] else config.decay))
	if fuel[i] > 0.0:
		var previous_fuel := fuel[i]
		fuel[i] = maxf(0.0, fuel[i] - maxf(intensity[i], 0.24) * _burn_rate[i] * config.consumption * dt)
		_burned_area += (previous_fuel - fuel[i]) / _initial_fuel[i]
	elif intensity[i] <= 0.001:
		_finish_burn(i)


func _finish_burn(i: int, remaining_heat: float = 0.0) -> void:
	state[i] = Burn.CHARRED if fuel[i] <= 0.0 else Burn.INTACT
	intensity[i] = 0.0
	heat[i] = remaining_heat if fuel[i] > 0.0 else 0.0
	burning_count -= 1


func scorch_at(i: int) -> float:
	if _initial_fuel[i] <= 0.0:
		return 0.0
	return 1.0 - fuel[i] / _initial_fuel[i]


func dampness_at(i: int) -> float:
	return clampf(moisture[i] - _initial_moisture[i], 0.0, 1.0)
