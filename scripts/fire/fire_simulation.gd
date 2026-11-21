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

var _initial_fuel := PackedFloat32Array()
var _initial_moisture := PackedFloat32Array()
var _burn_rate := PackedFloat32Array()
var _ignition_heat := PackedFloat32Array()
var _incoming := PackedFloat32Array()
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
	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed
	for i in count:
		var cell := Vector2i(i % grid.x, floori(float(i) / grid.x))
		var center := (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE
		terrain[i] = terrain_at.call(center)
		var profile: Vector3 = config.terrain_profiles.get(terrain[i], Vector3.ZERO)
		_initial_fuel[i] = maxf(0.0, profile.x) * rng.randf_range(0.83, 1.17)
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
	heat.fill(0.0)
	intensity.fill(0.0)
	state.fill(Burn.INTACT)
	burning_count = 0


func ignite(point: Vector2) -> bool:
	var i := index_at(point)
	if i < 0 or fuel[i] <= 0.0 or state[i] != Burn.INTACT:
		return false
	if not config.terrain_profiles.has(_terrain_at.call(point)):
		return false
	_ignite_cell(i)
	return true


func index_at(point: Vector2) -> int:
	if not _bounds.has_point(point):
		return -1
	return _index(Vector2i((point / CELL_SIZE).floor()))


func _index(cell: Vector2i) -> int:
	if not Rect2i(Vector2i.ZERO, grid).has_point(cell):
		return -1
	return cell.y * grid.x + cell.x


func _ignite_cell(i: int) -> void:
	state[i] = Burn.BURNING
	intensity[i] = config.max_intensity * 0.23
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


func step() -> void:
	var dt := 1.0 / config.tick_rate
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
			if target >= 0 and state[target] == Burn.INTACT and fuel[target] > 0.0:
				_incoming[target] += amount * weights[d]
	for i in fuel.size():
		if state[i] == Burn.BURNING:
			_burn(i, dt)
		elif state[i] == Burn.INTACT and fuel[i] > 0.0 and (_incoming[i] > 0.0 or heat[i] > 0.0):
			var warmed := heat[i] * retention + _incoming[i]
			heat[i] = warmed if warmed >= 0.0001 else 0.0
			var threshold := _ignition_heat[i] * (0.53 + 1.7 * moisture[i])
			if heat[i] >= threshold:
				_ignite_cell(i)


func _burn(i: int, dt: float) -> void:
	var target := config.max_intensity * minf(1.0, fuel[i] / 0.8) * (1.0 - moisture[i] * 0.42)
	intensity[i] = move_toward(intensity[i], target, dt * (config.growth if target > intensity[i] else config.decay))
	if fuel[i] > 0.0:
		fuel[i] = maxf(0.0, fuel[i] - maxf(intensity[i], 0.24) * _burn_rate[i] * config.consumption * dt)
	elif intensity[i] <= 0.001:
		state[i] = Burn.CHARRED
		heat[i] = 0.0
		burning_count -= 1


func scorch_at(i: int) -> float:
	if state[i] == Burn.INTACT:
		return 0.0
	return 1.0 - fuel[i] / _initial_fuel[i]
