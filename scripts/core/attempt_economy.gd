extends RefCounted

const Settings = preload("res://resources/balance/economy_configuration.gd")

var credits := 0
var price := 0
var income := 0.0
var _base_income := 0.0
var _territory_income := 0.0
var _fraction := 0.0
var _opening := 0


func configure(settings: Settings, discount: int = 0, income_bonus: int = 0, start_bonus: int = 0, fresh: bool = true) -> void:
	price = maxi(1, roundi(settings.cannon_price * (1.0 - discount / 100.0)))
	var opening := mini(settings.opening_credits + start_bonus, price * 2 - 1)
	credits = opening if fresh else maxi(0, credits + opening - _opening)
	_opening = opening
	var multiplier := 1.0 + income_bonus / 100.0
	_base_income = settings.base_income * multiplier
	_territory_income = settings.territory_income * multiplier
	income = _base_income + _territory_income
	if fresh:
		_fraction = 0.0


func advance(delta: float, burned_fraction: float) -> void:
	income = _base_income + _territory_income * (1.0 - clampf(burned_fraction, 0.0, 1.0))
	_fraction += income * delta
	var earned := floori(_fraction + 0.0000001)
	credits += earned
	_fraction -= earned


func can_buy() -> bool:
	return credits >= price


func spend() -> bool:
	if not can_buy():
		return false
	credits -= price
	return true
