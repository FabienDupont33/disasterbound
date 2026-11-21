extends Node2D

const Map = preload("res://resources/maps/le_hameau.gd")
const Simulation = preload("res://scripts/fire/fire_simulation.gd")
const Renderer = preload("res://scripts/fire/fire_renderer.gd")
const Configuration = preload("res://resources/balance/fire_configuration.gd")
const WIND_ARROWS := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]

@export var configuration: Configuration

var simulation := Simulation.new()
var running := false
var _accumulator := 0.0

@onready var _renderer: Renderer = $FireRenderer
@onready var _status: Label = $TestOverlay/Status


func _ready() -> void:
	simulation.setup(Map.SIZE, Map.fire_terrain_at, configuration)
	_renderer.setup(simulation, Map.SIZE, Map.fire_terrain_at)
	_reset()


func _physics_process(delta: float) -> void:
	if not running:
		return
	var interval := 1.0 / configuration.tick_rate
	_accumulator += delta
	if _accumulator + 0.000001 < interval:
		return
	var had_fire := simulation.burning_count > 0
	while _accumulator + 0.000001 >= interval:
		_accumulator = maxf(0.0, _accumulator - interval)
		simulation.step()
	if had_fire or simulation.burning_count > 0:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				running = not running
				_update_status()
			KEY_R:
				_reset()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if simulation.ignite(point):
			_refresh()


func _reset() -> void:
	running = false
	_accumulator = 0.0
	simulation.reset()
	if configuration.initial_ignition:
		simulation.ignite(configuration.initial_position)
	_refresh()


func _refresh() -> void:
	_renderer.refresh()
	_update_status()


func _update_status() -> void:
	var sector := posmod(roundi(configuration.wind_direction.angle() / (TAU / 8.0)), 8)
	var wind := "%s %d %%" % [WIND_ARROWS[sector], roundi(configuration.wind_strength * 100.0)]
	if configuration.wind_direction.is_zero_approx() or is_zero_approx(configuration.wind_strength):
		wind = "Calme"
	_status.text = "%s    Vent %s    Feu %d" % [
		"Active" if running else "Pause", wind, simulation.burning_count,
	]
