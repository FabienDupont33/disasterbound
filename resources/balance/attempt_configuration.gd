extends Resource

@export var village_max_hp := 100.0
@export var damage_radius := 30.0
@export var damage_per_second := 18.0
@export_range(0.0, 1.0) var additional_house_weight := 0.55
@export var victory_base_points := 40
@export var defeat_base_points := 5
@export var preservation_bonus := 25
@export var defeat_survival_cap := 15
@export var seconds_per_survival_point := 6.0
## Réglage propre au niveau. Le Hameau utilise les récompenses de référence.
@export var level_reward_multiplier := 1.0
