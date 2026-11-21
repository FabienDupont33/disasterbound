extends Camera2D

const Map = preload("res://resources/maps/le_hameau.gd")
@export var frame_margin := Vector2(16, 18)
@export var sidebar_width := 128.0
var _map_size := Map.SIZE


func use_map_size(map_size: Vector2) -> void:
	_map_size = map_size
	_frame_map()


func _ready() -> void:
	get_viewport().size_changed.connect(_frame_map)
	_frame_map()


func _frame_map() -> void:
	var view_size := get_viewport_rect().size
	var padded_size := _map_size + frame_margin * 2.0
	var fit := minf((view_size.x - sidebar_width) / padded_size.x, view_size.y / padded_size.y)
	position = _map_size * 0.5
	zoom = Vector2.ONE * (floorf(fit) if fit >= 1.0 else fit)
	offset.x = sidebar_width / (2.0 * zoom.x)
	force_update_scroll()
