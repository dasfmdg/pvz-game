class_name PlantShooter
extends PlantBase
## 射手类植物：豌豆射手 / 双发射手 / 寒冰射手 / 三重射手
## 行为差异由 id 与 PLANT_BEHAVIOR 驱动，避免为每个射手写重复代码

var _timer := 0.0
var _second_timer := -1.0
var _behavior: Dictionary = {}


func _on_planted() -> void:
	_behavior = GameConfig.PLANT_BEHAVIOR.get(plant_id, {})
	_timer = float(_behavior.get("first_fire", 0.6))


## 单局快照：射击主计时器与双发补射计时器
func snapshot_state() -> Dictionary:
	return {"t": _timer, "second_t": _second_timer}


func restore_state(data: Dictionary) -> void:
	_timer = float(data.get("t", _timer))
	_second_timer = float(data.get("second_t", -1.0))


func _tick(delta: float) -> void:
	if _second_timer >= 0.0:
		_second_timer -= delta
		if _second_timer <= 0.0:
			_second_timer = -1.0
			_fire_peas()

	_timer -= delta
	if _timer > 0.0:
		return
	if not _has_target():
		return
	_timer = float(_behavior.get("fire_interval", 1.5))
	_fire_peas()
	if plant_id == "repeater":
		_second_timer = float(_behavior.get("second_delay", 0.13))


## 该植物覆盖的行（三重射手覆盖三行）
func _target_rows() -> Array[int]:
	var rows: Array[int] = []
	if plant_id == "threepeater":
		for row in [cell.y - 1, cell.y, cell.y + 1]:
			if row >= 0 and row < GameConfig.ROWS:
				rows.append(row)
	else:
		rows.append(cell.y)
	return rows


func _has_target() -> bool:
	for row in _target_rows():
		for zombie in game.zombies_in_lane(row):
			if zombie.position.x > position.x:
				return true
	return false


func _fire_peas() -> void:
	var damage := int(_behavior.get("damage", 20))
	var is_ice := plant_id == "snowpea"
	for row in _target_rows():
		var has_target := false
		for zombie in game.zombies_in_lane(row):
			if zombie.position.x > position.x:
				has_target = true
				break
		if not has_target:
			continue
		game.spawn_bullet(row, position.x + 30.0, GameConfig.cell_center_y(row), damage, is_ice)