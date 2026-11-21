extends Control

const Economy = preload("res://scripts/core/attempt_economy.gd")

signal cannon_requested

@onready var _slot: Button = $Center/Equipment/Cannon
@onready var _icon: Node2D = $Center/Equipment/Cannon/Icon
@onready var _price: Label = $Center/Equipment/Cannon/Price
@onready var _credits: Label = $Balance/Credits
@onready var _income: Label = $Balance/Income


func _ready() -> void:
	_slot.pressed.connect(func(): cannon_requested.emit())
	var normal: StyleBoxFlat = _slot.get_theme_stylebox("normal")
	var selected: StyleBoxFlat = normal.duplicate()
	selected.bg_color = Color("#23483f")
	selected.border_color = Color("#a9e9c8")
	selected.set_border_width_all(2)
	_slot.add_theme_stylebox_override("pressed", selected)
	_slot.add_theme_stylebox_override("hover_pressed", selected)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("#1d2726")
	disabled.border_color = Color("#3a4948")
	_slot.add_theme_stylebox_override("disabled", disabled)


func refresh(economy: Economy, selected: bool, open: bool) -> void:
	_slot.disabled = not open or not economy.can_buy()
	_slot.set_pressed_no_signal(selected and not _slot.disabled)
	_price.text = str(economy.price)
	_price.modulate = Color("#899392") if _slot.disabled else Color("#f5d799")
	_icon.modulate = Color("#717777") if _slot.disabled else Color.WHITE
	_credits.text = "Crédits  %d" % economy.credits
	var rate := ("%.1f" % economy.income).replace(".", ",")
	_income.text = "+%s crédits / s" % rate if open else "Revenu arrêté"
	_slot.tooltip_text = "Canon à eau · %d crédits" % economy.price
