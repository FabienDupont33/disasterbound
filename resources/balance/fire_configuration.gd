extends Resource

## Profils (combustible en unités, humidité de 0 à 1, vitesse de combustion).
@export var terrain_profiles: Dictionary[StringName, Vector3] = {
	&"forest": Vector3(13.0, 0.34, 1.0),
	&"meadow": Vector3(4.3, 0.26, 1.4),
	&"dry_grass": Vector3(2.8, 0.08, 1.65),
}
@export_range(2, 30) var tick_rate := 10
@export var propagation := 1.8
@export var heat_loss := 0.24
@export var growth := 2.1
@export var decay := 1.5
@export var consumption := 1.0
@export var max_intensity := 1.0
@export var wind_direction := Vector2(1, 0.45)
@export_range(0.0, 1.0) var wind_strength := 0.48
@export var wind_influence := 1.15
@export var seed := 408
@export var initial_ignition := true
@export var initial_position := Vector2(105, 59)
