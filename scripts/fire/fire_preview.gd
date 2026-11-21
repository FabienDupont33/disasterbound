extends Node2D

const Map = preload("res://resources/maps/le_hameau.gd")
const Levels = preload("res://resources/maps/fire_levels.gd")
const Simulation = preload("res://scripts/fire/fire_simulation.gd")
const Renderer = preload("res://scripts/fire/fire_renderer.gd")
const Configuration = preload("res://resources/balance/fire_configuration.gd")
const Cannon = preload("res://scripts/defenses/water_cannon.gd")
const CannonConfiguration = preload("res://resources/balance/water_cannon_configuration.gd")
const CannonRenderer = preload("res://scripts/defenses/water_cannon_renderer.gd")
const Placement = preload("res://scripts/defenses/cannon_placement.gd")
const Attempt = preload("res://scripts/objectives/fire_attempt.gd")
const AttemptConfig = preload("res://resources/balance/attempt_configuration.gd")
const AttemptPanel = preload("res://scripts/ui/attempt_panel.gd")
const TechnologyPanel = preload("res://scripts/ui/fire_technology_panel.gd")
const Economy = preload("res://scripts/core/attempt_economy.gd")
const EconomyConfig = preload("res://resources/balance/economy_configuration.gd")
const EquipmentBar = preload("res://scripts/ui/equipment_bar.gd")
const WIND_ARROWS := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
const SPEEDS := [1.0, 2.0, 4.0]

@export var configuration: Configuration
@export var cannon_configuration: CannonConfiguration
@export var attempt_configuration: AttemptConfig
@export var economy_configuration := EconomyConfig.new()

var simulation := Simulation.new()
var attempt: Attempt
var running := false
var started := false
var cannons: Array[Cannon] = []
var _cannon_views: Array[CannonRenderer] = []
var _placing := false
var _preview_point := Vector2.INF
var _preview_efficiency := 0.0
var _accumulator := 0.0
var _effective_cannon: CannonConfiguration
var economy := Economy.new()
var level_id := Levels.FIRST
var _map: Script = Map
var _base_fire: Configuration
var _starts: Array[Vector2] = []
var _dev_second := false
var _speed_index := 0

@onready var _renderer: Renderer = $FireRenderer
@onready var _cannon_renderer: CannonRenderer = $CannonRenderer
@onready var _status: Label = $TestOverlay/Status
@onready var _attempt_panel: AttemptPanel = $TestOverlay/AttemptPanel
@onready var _technology: TechnologyPanel = $TestOverlay/FireTechnologyPanel
@onready var _equipment: EquipmentBar = $TestOverlay/EquipmentBar
@onready var _village_objects := $"../LeHameau/Objects"
@onready var _village_effects := $"../LeHameau/Effects"


func _ready() -> void:
	_base_fire = configuration
	attempt = Attempt.new(attempt_configuration, [])
	_attempt_panel.restart_requested.connect(_reset)
	_attempt_panel.technology_requested.connect(_open_technology)
	_technology.purchase_requested.connect(_purchase_technology)
	_attempt_panel.level_requested.connect(_select_level)
	_attempt_panel.speed_requested.connect(_set_speed)
	_equipment.cannon_requested.connect(_toggle_placement)
	_dev_second = OS.is_debug_build() and "--level=2" in OS.get_cmdline_user_args()
	_load_level(Levels.SECOND if _dev_second else Levels.FIRST)


func _select_level(index: int) -> void:
	if not _between_attempts():
		return
	match index:
		0: _load_level(Levels.FIRST)
		1:
			if _second_unlocked():
				_load_level(Levels.SECOND)
		2: _load_level(Levels.EXPERIMENT)


func _second_unlocked() -> bool:
	return _dev_second or attempt.progression.hameau_completed


func _load_level(id: StringName) -> void:
	level_id = id
	var level: Dictionary = Levels.LEVELS[id]
	_map = level.map
	$"../Camera2D".use_map_size(_map.SIZE)
	_cannon_renderer.map_size = _map.SIZE
	configuration = _base_fire.duplicate()
	_starts.clear()
	if id == Levels.FIRST:
		if configuration.initial_ignition:
			_starts.append(configuration.initial_position)
	else:
		_starts.assign(level.starts)
		configuration.initial_radius = level.radius
		configuration.initial_intensity = level.intensity
	configuration.seed = level.get("seed", configuration.seed)
	configuration.wind_direction = level.wind
	configuration.wind_strength = level.strength
	for layer in $"../LeHameau".get_children():
		layer.use_map(_map)
	var houses: Array[Rect2] = []
	for origin: Vector2 in _map.HOUSE_ORIGINS:
		houses.append(Rect2(origin, _map.HOUSE_SIZE))
	attempt.use_level(id, houses)
	attempt.awards_progress = id != Levels.EXPERIMENT
	var terrain_at := Callable(_map, "fire_terrain_at")
	simulation.setup(_map.SIZE, terrain_at, configuration)
	_renderer.setup(simulation, _map.SIZE, terrain_at)
	_reset()


func _draw() -> void:
	if started:
		return
	for point in _starts:
		var radius := configuration.initial_radius
		draw_circle(point, radius, Color(0.90, 0.35, 0.10, 0.14))
		for i in 8:
			var angle := i * TAU / 8.0
			draw_arc(point, radius, angle, angle + 0.50, 6, Color("#ffce82"), 1.0)
		var diamond := PackedVector2Array([point + Vector2(0, -8), point + Vector2(7, 0),
			point + Vector2(0, 8), point + Vector2(-7, 0)])
		draw_colored_polygon(diamond, Color("#604135"))
		draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 5)), Color("#f58346"))
		draw_rect(Rect2(point - Vector2(0, 4), Vector2(2, 6)), Color("#ffd276"))


func _process(_delta: float) -> void:
	if _can_place() and not _technology.visible:
		var point := get_local_mouse_position().round()
		if point != _preview_point:
			_update_placement(point)


func _physics_process(delta: float) -> void:
	if not running:
		return
	var interval := 1.0 / configuration.tick_rate
	_accumulator += delta * SPEEDS[_speed_index]
	if _accumulator + 0.000001 < interval:
		return
	var had_effects := simulation.burning_count > 0 or simulation.wet_count > 0
	while _accumulator + 0.000001 >= interval:
		_accumulator = maxf(0.0, _accumulator - interval)
		for cannon in cannons:
			cannon.step(simulation, interval)
		simulation.step()
		attempt.step(simulation, interval)
		if attempt.outcome != Attempt.Outcome.PENDING:
			_finish_attempt()
			return
		economy.advance(interval, simulation.burned_fraction())
	if had_effects or simulation.burning_count > 0 or simulation.wet_count > 0:
		_refresh()
	elif running:
		_update_status()
	if _can_place() and _preview_point != Vector2.INF:
		_update_placement(_preview_point)


func _unhandled_input(event: InputEvent) -> void:
	if _technology.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_T]:
			_technology.hide()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				if attempt.outcome != Attempt.Outcome.PENDING:
					return
				if not started:
					for point in _starts:
						simulation.ignite_area(point, configuration.initial_radius, configuration.initial_intensity)
					attempt.observe_ignition(simulation)
					_attempt_panel.set_technology_available(false)
				started = true
				_update_level_panel()
				_attempt_panel.update_speed(_speed_index, true)
				queue_redraw()
				running = not running
				for view in _cannon_views:
					view.running = running
				_cannon_renderer.preview_visible = false
				_refresh()
			KEY_R:
				_reset()
			KEY_T:
				_open_technology()
			KEY_1:
				_toggle_placement()
			KEY_ESCAPE:
				_set_placement(false)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_set_placement(false)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
			if _placing:
				_try_place(point.round())
			elif event.shift_pressed and OS.is_debug_build() and started and level_id != Levels.EXPERIMENT \
					and attempt.outcome == Attempt.Outcome.PENDING and simulation.ignite(point):
				attempt.observe_ignition(simulation)
				_refresh()


func _toggle_placement() -> void:
	_set_placement(not _placing)


func _set_placement(enabled: bool) -> void:
	_placing = enabled and _can_buy()
	_preview_point = Vector2.INF
	_cannon_renderer.preview_visible = false
	_update_status()


func _try_place(point: Vector2) -> void:
	if not _can_place() or not Placement.allowed(point, simulation, cannons, _map):
		return
	var cannon := Cannon.new(_effective_cannon, point, _efficiency(point))
	if not economy.spend():
		return
	cannons.append(cannon)
	var view := CannonRenderer.new()
	view.cannon = cannon
	view.running = running
	view.time_scale = SPEEDS[_speed_index]
	_cannon_views.append(view)
	add_child(view)
	_set_placement(true)


func _can_place() -> bool:
	return _placing and _can_buy()


func _can_buy() -> bool:
	return attempt.outcome == Attempt.Outcome.PENDING and (not started or running) and economy.can_buy()


func _can_research() -> bool:
	return level_id != Levels.EXPERIMENT and _between_attempts()


func _between_attempts() -> bool:
	return not started or attempt.outcome != Attempt.Outcome.PENDING


func _open_technology() -> void:
	if _can_research():
		_cannon_renderer.preview_visible = false
		_preview_point = Vector2.INF
		_technology.refresh(attempt.progression)
		_technology.show()


func _purchase_technology(id: StringName, expected_level: int) -> void:
	if not _can_research() or not _technology.visible:
		return
	if attempt.progression.purchase(id, expected_level):
		if not started:
			_apply_progression(false)
			attempt.reset()
			_refresh()
		else:
			_attempt_panel.update_reward_balance(attempt)
		_technology.animate_purchase()
	_technology.refresh(attempt.progression)


func _apply_progression(fresh_economy: bool = true) -> void:
	if level_id == Levels.EXPERIMENT:
		_effective_cannon = cannon_configuration.duplicate()
		attempt.config = attempt_configuration.duplicate()
		economy.configure(Levels.economy_for(level_id, economy_configuration))
	else:
		_effective_cannon = attempt.progression.effective_cannon(cannon_configuration)
		attempt.config = attempt.progression.effective_attempt(attempt_configuration)
		economy.configure(economy_configuration, attempt.progression.bonus(&"discount"),
				attempt.progression.bonus(&"income"), attempt.progression.bonus(&"startup"), fresh_economy)
	attempt.config.level_reward_multiplier = Levels.LEVELS[level_id].reward
	_cannon_renderer.preview_range = _effective_cannon.range_px
	for cannon in cannons:
		cannon.config = _effective_cannon
		cannon.hp = _effective_cannon.max_hp


func _efficiency(point: Vector2) -> float:
	return cannon_configuration.efficiency_at_distance(_map.distance_to_water(point))


func _update_placement(point: Vector2) -> void:
	_preview_point = point
	_cannon_renderer.preview_visible = Rect2(Vector2.ZERO, _map.SIZE).has_point(point)
	_cannon_renderer.preview_valid = _cannon_renderer.preview_visible and Placement.allowed(point, simulation, cannons, _map)
	_cannon_renderer.preview_position = point
	_preview_efficiency = _efficiency(point) if _cannon_renderer.preview_valid else 0.0
	_update_status()


func _reset() -> void:
	running = false
	started = false
	cannons.clear()
	for view in _cannon_views:
		remove_child(view)
		view.queue_free()
	_cannon_views.clear()
	_placing = false
	_preview_point = Vector2.INF
	_cannon_renderer.preview_visible = false
	_technology.hide()
	_accumulator = 0.0
	_set_speed(0)
	simulation.reset()
	_apply_progression()
	attempt.reset()
	_attempt_panel.reset()
	_attempt_panel.set_technology_available(_can_research())
	_update_level_panel()
	queue_redraw()
	_renderer.set_process(true)
	_refresh()


func _finish_attempt() -> void:
	running = false
	_placing = false
	_cannon_renderer.preview_visible = false
	_renderer.set_process(false)
	var destroyed := 0
	for view in _cannon_views:
		view.running = false
		view.cannon.spraying = false
		if view.cannon.hp <= 0.0:
			destroyed += 1
	_refresh()
	_attempt_panel.show_result(attempt, _burned_percent(), destroyed, level_id == Levels.SECOND and simulation.exited_map)
	_attempt_panel.update_speed(_speed_index, false)
	_attempt_panel.set_technology_available(_can_research())
	_update_level_panel()


func _set_speed(index: int) -> void:
	_speed_index = clampi(index, 0, SPEEDS.size() - 1)
	var speed: float = SPEEDS[_speed_index]
	_renderer.time_scale = speed
	_village_effects.time_scale = speed
	for view in _cannon_views:
		view.time_scale = speed
	_attempt_panel.update_speed(_speed_index, started and attempt.outcome == Attempt.Outcome.PENDING)


func _update_level_panel() -> void:
	var index := [Levels.FIRST, Levels.SECOND, Levels.EXPERIMENT].find(level_id)
	_attempt_panel.update_levels(Levels.LEVELS[level_id].name, index,
			_second_unlocked(), _between_attempts())


func _burned_percent() -> int:
	return floori(simulation.burned_fraction() * 100.0 + 0.0001)


func _refresh() -> void:
	_renderer.refresh()
	for i in _map.HOUSE_ORIGINS.size():
		var stage := attempt.house_damage_stage(i)
		_village_objects.set_house_stage(i, stage)
		_village_effects.set_house_stage(i, stage)
	_attempt_panel.update_hud(attempt, _burned_percent())
	_update_status()


func _update_status() -> void:
	if _placing and not economy.can_buy():
		_placing = false
		_cannon_renderer.preview_visible = false
		_preview_point = Vector2.INF
	_equipment.refresh(economy, _placing, attempt.outcome == Attempt.Outcome.PENDING and (not started or running))
	var sector := posmod(roundi(configuration.wind_direction.angle() / (TAU / 8.0)), 8)
	var wind := "vers %s %d %%" % [WIND_ARROWS[sector], roundi(configuration.wind_strength * 100.0)]
	if configuration.wind_direction.is_zero_approx() or is_zero_approx(configuration.wind_strength):
		wind = "Calme"
	var operational := 0
	for cannon in cannons:
		if cannon.hp > 0.0:
			operational += 1
	var cannon_status := "Canons actifs %d/%d" % [operational, cannons.size()]
	if _can_place() and _cannon_renderer.preview_visible:
		if _cannon_renderer.preview_valid:
			cannon_status += " · Rendement %d %%" % roundi(_preview_efficiency * 100.0)
		else:
			cannon_status += " · Emplacement interdit"
	var phase := "Préparation"
	if attempt.outcome != Attempt.Outcome.PENDING:
		phase = "Terminée"
	elif started:
		phase = "Active" if running else "Pause"
	_status.text = "%s    Vent %s    Feu %d    %s" % [
		phase,
		wind, simulation.burning_count, cannon_status,
	]
