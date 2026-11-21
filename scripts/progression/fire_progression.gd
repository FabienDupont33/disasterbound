extends RefCounted

const Technologies = preload("res://resources/balance/fire_technologies.gd")
const CannonConfig = preload("res://resources/balance/water_cannon_configuration.gd")
const AttemptConfig = preload("res://resources/balance/attempt_configuration.gd")
const SAVE_PATH := "user://fire_points.cfg"
const SECTION := "fire_sphere"
const VERSION := 1
const MAX_INTEGER := 9223372036854775807

var points := 0
var save_error := OK
var migrated := false
var refunded_points := 0
var hameau_completed := false
var _levels: Dictionary[StringName, int] = {}
var _file := ConfigFile.new()
var _path: String
var _read_error := OK


func _init(path: String = SAVE_PATH) -> void:
	_path = path
	var loaded := _file.load(path)
	if loaded != OK and loaded != ERR_FILE_NOT_FOUND:
		_read_error = loaded
		save_error = loaded
		return
	points = _safe_int(_file.get_value("fire", "technology_points", 0), MAX_INTEGER)
	hameau_completed = _file.get_value("fire", "hameau_completed", false) == true
	if _file.has_section_key(SECTION, "version"):
		if _file.get_value(SECTION, "version") != VERSION:
			_read_error = ERR_FILE_UNRECOGNIZED
			save_error = _read_error
			return
		for id: StringName in Technologies.NODES:
			_levels[id] = _safe_int(_file.get_value(SECTION, id, 0), Technologies.NODES[id].max)
	elif _file.has_section("fire_technologies"):
		_migrate_legacy()


func _migrate_legacy() -> void:
	for id: StringName in Technologies.LEGACY_COSTS:
		var deployment := id == &"deployment"
		var old_level := _safe_int(_file.get_value("fire_technologies", id, 0), 3 if deployment else 10)
		var kept := 0 if deployment else mini(old_level, Technologies.NODES[id].max)
		if kept > 0:
			_levels[id] = kept
		for old_rank in range(kept, old_level):
			refunded_points += roundi(Technologies.LEGACY_COSTS[id] * pow(1.5, old_rank))
	refunded_points = mini(refunded_points, MAX_INTEGER - points)
	points += refunded_points
	migrated = true
	_save(points, _levels)


func _safe_int(value: Variant, maximum: int) -> int:
	return clampi(value, 0, maximum) if value is int else 0


func level(id: StringName) -> int:
	return _levels.get(id, 0)


func can_purchase(id: StringName) -> bool:
	return (_read_error == OK and Technologies.NODES.has(id)
			and level(id) < Technologies.NODES[id].max
			and requirements_met(id) and points >= Technologies.cost(id, level(id)))


func requirements_met(id: StringName) -> bool:
	var requirements: Dictionary = Technologies.NODES[id].requires
	for dependency: StringName in requirements:
		if level(dependency) < requirements[dependency]:
			return false
	return true


func purchase(id: StringName, expected_level: int) -> bool:
	if expected_level != level(id) or not can_purchase(id):
		return false
	var next_points := points - Technologies.cost(id, expected_level)
	var next_levels := _levels.duplicate()
	next_levels[id] = expected_level + 1
	if not _save(next_points, next_levels):
		return false
	points = next_points
	_levels = next_levels
	return true


func credit(amount: int, completed_level: StringName = &"") -> void:
	points += clampi(amount, 0, MAX_INTEGER - points)
	hameau_completed = hameau_completed or completed_level == &"hameau"
	_save(points, _levels)


func _save(amount: int, levels: Dictionary[StringName, int]) -> bool:
	if _read_error != OK:
		return false
	var updated := ConfigFile.new()
	updated.parse(_file.encode_to_text())
	updated.set_value("fire", "technology_points", amount)
	updated.set_value("fire", "hameau_completed", hameau_completed)
	updated.set_value(SECTION, "version", VERSION)
	for id: StringName in Technologies.NODES:
		updated.set_value(SECTION, id, levels.get(id, 0))
	var temporary := _path + ".tmp"
	save_error = updated.save(temporary)
	if save_error == OK:
		save_error = DirAccess.rename_absolute(temporary, _path)
	if save_error == OK:
		_file = updated
	return save_error == OK


func effective_cannon(base: CannonConfig) -> CannonConfig:
	var effective: CannonConfig = base.duplicate()
	effective.extinguishing_power *= _multiplier(&"power")
	effective.range_px *= _multiplier(&"range")
	effective.rotation_speed *= _multiplier(&"cadence")
	effective.max_hp *= _multiplier(&"armor")
	return effective


func effective_attempt(base: AttemptConfig) -> AttemptConfig:
	var effective: AttemptConfig = base.duplicate()
	effective.village_max_hp *= _multiplier(&"village")
	return effective


## Tous les bonus d'une même statistique s'additionnent avant d'être appliqués à la base.
func bonus(stat: StringName) -> int:
	var result := 0
	for id: StringName in Technologies.NODES:
		var node: Dictionary = Technologies.NODES[id]
		if node.stat == stat:
			result += node.step * level(id)
	return result


func _multiplier(stat: StringName) -> float:
	return 1.0 + bonus(stat) / 100.0
