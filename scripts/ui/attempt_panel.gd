extends PanelContainer

const Attempt = preload("res://scripts/objectives/fire_attempt.gd")
signal restart_requested
signal technology_requested
signal level_requested(index: int)
signal speed_requested(index: int)

@onready var _hp: ProgressBar = $Body/Health
@onready var _hp_text: Label = $Body/HealthText
@onready var _territory: Label = $Body/Territory
@onready var _result: VBoxContainer = $Body/Result
@onready var _headline: Label = $Body/Result/Headline
@onready var _details: Label = $Body/Result/Details
@onready var _points: Label = $Body/Result/Points
@onready var _save_notice: Label = $Body/Result/SaveNotice
@onready var _restart: Button = $Body/Result/Restart


func _ready() -> void:
	_restart.pressed.connect(func(): restart_requested.emit())
	$Body/Technology.pressed.connect(func(): technology_requested.emit())
	$Body/Level.item_selected.connect(func(index: int): level_requested.emit(index))
	$Body/Speed.item_selected.connect(func(index: int): speed_requested.emit(index))


func update_levels(title: String, active_index: int, second_unlocked: bool, can_select: bool) -> void:
	var heading: Label = $Body/Title
	heading.text = title if active_index != 2 else "Prototype\n" + title
	heading.add_theme_font_size_override("font_size", 12 if active_index == 2 else 14)
	var selector: OptionButton = $Body/Level
	selector.set_item_text(1, "2 · La Vallée des Pins (débloqué)" if second_unlocked else "2 · La Vallée des Pins (verrouillé)")
	selector.set_item_disabled(1, not second_unlocked)
	selector.select(active_index)
	selector.text = "Niveaux"
	selector.visible = can_select
	set_deferred("size", Vector2(size.x, 0.0))


func set_technology_available(available: bool) -> void:
	$Body/Technology.visible = available
	set_deferred("size", Vector2(size.x, 0.0))


func update_hud(attempt: Attempt, burned_percent: int) -> void:
	_hp.max_value = attempt.config.village_max_hp
	_hp.value = attempt.hp
	_hp_text.text = "%d / %d PV" % [ceili(attempt.hp), roundi(attempt.config.village_max_hp)]
	_hp.modulate = Color("#ff9e89") if attempt.exposed or attempt.hp <= 0.0 else Color("#b9e4a6")
	_territory.text = "Territoire brûlé\n%d %%" % burned_percent


func show_result(attempt: Attempt, burned_percent: int, destroyed: int, escaped: bool = false) -> void:
	var victory := attempt.outcome == Attempt.Outcome.VICTORY
	_headline.text = "Victoire" if victory else "Défaite"
	_headline.modulate = Color("#bae5a8") if victory else Color("#ffac97")
	var tenths := roundi(attempt.elapsed * 10.0)
	_details.text = "%d:%02d,%d de survie\n%d %% brûlé\n%d %% préservé\n%d canon(s) détruit(s)" % [
		floori(tenths / 600.0), floori(tenths / 10.0) % 60, tenths % 10,
		burned_percent, 100 - burned_percent, destroyed,
	]
	if escaped:
		_details.text += "\nFeu hors zone"
	update_reward_balance(attempt)
	_result.show()


func update_speed(index: int, visible_during_attempt: bool) -> void:
	var speed: OptionButton = $Body/Speed
	speed.select(index)
	speed.visible = visible_during_attempt
	set_deferred("size", Vector2(size.x, 0.0))


func update_reward_balance(attempt: Attempt) -> void:
	_points.visible = attempt.awards_progress
	_points.text = "+%d points techno\nTotal incendie  %d" % [attempt.awarded_points, attempt.total_points]
	_save_notice.visible = attempt.awards_progress and attempt.save_error != OK


func reset() -> void:
	_result.hide()
	set_deferred("size", Vector2(size.x, 0.0))
