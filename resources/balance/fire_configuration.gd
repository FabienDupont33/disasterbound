extends Resource

## Profils (combustible en unités, humidité de 0 à 1, vitesse de combustion).
@export var terrain_profiles: Dictionary[StringName, Vector3] = {
	&"forest": Vector3(15.5, 0.34, 0.95),
	&"meadow": Vector3(4.3, 0.20, 1.4),
	&"dry_grass": Vector3(2.8, 0.08, 1.65),
}
@export_range(2, 30) var tick_rate := 10
@export var propagation := 0.88
@export var prairie_intensity_factor := 0.84
@export var heat_loss := 0.24
@export var growth := 2.1
@export var decay := 1.5
@export var consumption := 1.0
@export var max_intensity := 1.0
@export var drying_per_second := 0.034
@export var wind_direction := Vector2(1, 0.45)
@export_range(0.0, 1.0) var wind_strength := 0.48
@export var wind_influence := 1.55
@export var seed := 408
@export var initial_ignition := true
@export var initial_position := Vector2(78, 63)
@export_range(1.0, 70.0) var initial_radius := 16.0
@export_range(0.05, 1.0) var initial_intensity := 0.78
@export var water_resistance := 1.65
@export var water_fuel_reference := 15.5
@export var water_overlap_reference := 3.5
@export var residual_heat := 0.32
