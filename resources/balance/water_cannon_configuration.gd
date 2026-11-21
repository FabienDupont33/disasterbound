extends Resource

@export var range_px := 100.0
@export var extinguishing_power := 1.75
@export var flow_per_second := 2.4
@export var rotation_speed := 5.5 # radians par seconde
@export var splash_radius := 10.0
@export var max_hp := 46.0
@export var exposure_radius := 14.0
@export var heat_damage_per_second := 31.0
@export var near_water_px := 58.0
@export var far_water_px := 145.0
@export_range(0.0, 1.0) var medium_efficiency := 0.82
@export_range(0.0, 1.0) var far_efficiency := 0.65


func efficiency_at_distance(distance: float) -> float:
	if distance <= near_water_px:
		return 1.0
	if distance <= far_water_px:
		return medium_efficiency
	return far_efficiency
