extends Node2D

const Simulation = preload("res://scripts/fire/fire_simulation.gd")
const PIXEL_FIRE = preload("res://art/fire/pixel_fire.gdshader")

var _simulation: Simulation
var _map_size: Vector2
var _shader_material := ShaderMaterial.new()
var _texture: ImageTexture
var _pixels := PackedByteArray()
var _time := 0.0
var time_scale := 1.0


func setup(simulation: Simulation, map_size: Vector2, terrain_at: Callable) -> void:
	_simulation = simulation
	_map_size = map_size
	_pixels.resize(simulation.grid.x * simulation.grid.y * 3)
	_texture = ImageTexture.create_from_image(_field_image())
	var mask := PackedByteArray()
	mask.resize(int(map_size.x * map_size.y))
	for y in int(map_size.y):
		for x in int(map_size.x):
			var terrain: StringName = terrain_at.call(Vector2(x + 0.5, y + 0.5))
			mask[y * int(map_size.x) + x] = 255 if simulation.config.terrain_profiles.has(terrain) else 0
	var mask_image := Image.create_from_data(int(map_size.x), int(map_size.y), false, Image.FORMAT_R8, mask)
	_shader_material.shader = PIXEL_FIRE
	_shader_material.set_shader_parameter("field_size", _map_size)
	_shader_material.set_shader_parameter("fire_data", _texture)
	_shader_material.set_shader_parameter("terrain_mask", ImageTexture.create_from_image(mask_image))
	material = _shader_material
	queue_redraw()


func refresh() -> void:
	var maximum := maxf(0.001, _simulation.config.max_intensity)
	for i in _simulation.state.size():
		_pixels[i * 3] = roundi(255.0 * _simulation.intensity[i] / maximum)
		_pixels[i * 3 + 1] = roundi(255.0 * _simulation.scorch_at(i))
		_pixels[i * 3 + 2] = roundi(255.0 * _simulation.dampness_at(i))
	_texture.update(_field_image())


func _field_image() -> Image:
	return Image.create_from_data(_simulation.grid.x, _simulation.grid.y, false, Image.FORMAT_RGB8, _pixels)


func _process(delta: float) -> void:
	if _simulation == null or _simulation.burning_count == 0:
		return
	_time += delta * time_scale
	_shader_material.set_shader_parameter("flicker_time", floorf(_time * 14.0) / 14.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _map_size), Color.WHITE)
