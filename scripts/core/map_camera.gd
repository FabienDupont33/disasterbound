extends Camera2D

@export var map_size := Vector2(640, 360)
@export var pan_speed := 220.0
@export var pan_response := 14.0
@export_range(1, 5) var max_zoom := 3

var _center: Vector2
var _target: Vector2
var _zoom_step := 1


func _ready() -> void:
	_center = position
	_target = position


func _process(delta: float) -> void:
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	_target = _bounded(_target + direction.normalized() * pan_speed * delta / zoom.x, zoom.x)
	_center = _bounded(_center.lerp(_target, 1.0 - exp(-pan_response * delta)), zoom.x)
	position = _center.round()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(_zoom_step + 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(_zoom_step - 1)


func _set_zoom(step: int) -> void:
	step = clampi(step, 1, max_zoom)
	if step == _zoom_step:
		return
	var cursor_offset := get_local_mouse_position()
	_zoom_step = step
	_center = _bounded(position + cursor_offset * (1.0 - zoom.x / step), step)
	_target = _center
	zoom = Vector2.ONE * step
	position = _center.round()


func _bounded(point: Vector2, scale_factor: float) -> Vector2:
	var half_view := (get_viewport_rect().size / (2.0 * scale_factor)).min(map_size / 2.0).ceil()
	return point.clamp(half_view, map_size - half_view)
