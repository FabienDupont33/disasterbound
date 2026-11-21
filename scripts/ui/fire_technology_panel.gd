extends ColorRect

const Technologies = preload("res://resources/balance/fire_technologies.gd")
const Progression = preload("res://scripts/progression/fire_progression.gd")
const Graph = preload("res://scripts/ui/fire_technology_graph.gd")
const ICONS := {&"power":"✦", &"range":"◎", &"cadence":"↻", &"armor":"⬟", &"village":"✚",
	&"discount":"◆", &"income":"◆", &"startup":"◆"}

signal purchase_requested(id: StringName, expected_level: int)

var _progression: Progression
var _selected: StringName = &"power"
var _last_buy := -1000

@onready var _balance: Label = $Panel/Body/Header/Balance
@onready var _notice: Label = $Panel/Body/Footer/Notice
@onready var _graph: Graph = $Panel/Body/Content/Graph
@onready var _details: VBoxContainer = $Panel/Body/Content/Details/Body
@onready var _buy: Button = _details.get_node("Buy")


func _ready() -> void:
	$Panel/Body/Header/Close.pressed.connect(hide)
	$Panel/Body/Header/Recenter.pressed.connect(_graph.recenter)
	_graph.node_selected.connect(_select)
	_buy.pressed.connect(_on_buy)


func refresh(progression: Progression) -> void:
	_progression = progression
	_balance.text = "%d points disponibles" % progression.points
	_notice.text = ""
	if progression.save_error != OK:
		_notice.text = "Sauvegarde indisponible"
	elif progression.migrated:
		_notice.text = "Ancienne progression transférée · %d points remboursés" % progression.refunded_points
	_notice.visible = not _notice.text.is_empty()
	_graph.progression = progression
	_select(_selected)


func animate_purchase() -> void:
	_graph.pulse()


func _select(id: StringName) -> void:
	_selected = id
	_graph.selected = id
	_graph.queue_redraw()
	var node: Dictionary = Technologies.NODES[id]
	var rank := _progression.level(id)
	var capped: bool = rank >= node.max
	var unlocked := _progression.requirements_met(id)
	_details.get_node("Title").text = "%s  %s" % [ICONS[node.stat], node.title]
	_details.get_node("Effect").text = Technologies.EFFECTS[node.stat]
	var state := "MAX" if capped else "Accessible" if unlocked else "Verrouillé"
	_details.get_node("Rank").text = "%d/%d · %s" % [rank, node.max, state]
	var current := "+%d %%" % (node.step * rank)
	var next := "+%d %%" % (node.step * (rank + 1))
	if node.stat == &"discount":
		current = "−%d %%" % (node.step * rank)
		next = "−%d %%" % (node.step * (rank + 1))
	elif node.stat == &"startup":
		current = "+%d crédits" % (node.step * rank)
		next = "+%d crédits" % (node.step * (rank + 1))
	var benefit := "Actuel · %s" % current
	if not capped:
		benefit += "\nProchain · %s\nCoût · %d points" % [next, Technologies.cost(id, rank)]
	_details.get_node("Benefit").text = benefit
	var requirements: Array[String] = []
	var dependencies: Dictionary = node.requires
	for dependency: StringName in dependencies:
		var needed: int = dependencies[dependency]
		var owned := _progression.level(dependency)
		var mark := "✓" if owned >= needed else "–"
		var prerequisite: Dictionary = Technologies.NODES[dependency]
		requirements.append("%s %s · requis %d/%d" % [mark, prerequisite.title, needed, prerequisite.max])
	_details.get_node("Requires").text = "Prérequis\n" + "\n".join(requirements) if not requirements.is_empty() else "Relié au noyau"
	var can_buy := _progression.can_purchase(id)
	_buy.disabled = not can_buy
	if capped:
		_buy.text = "MAX"
	elif not unlocked:
		_buy.text = "Prérequis manquants"
	elif _progression.points < Technologies.cost(id, rank):
		_buy.text = "Points insuffisants"
	else:
		_buy.text = "Acheter"


func _on_buy() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_buy < 500:
		return
	_last_buy = now
	purchase_requested.emit(_selected, _progression.level(_selected))
