class_name PlantMelonPult
extends PlantBase
## 西瓜投手：同行前方存在可命中僵尸时投掷西瓜（高直伤 + 相邻行溅射）
## 射速 / 首发 / 伤害参数集中在 GameConfig.PLANT_BEHAVIOR，本类只负责触发时机
## 本体素材为静态单图 melon.png，由 PlantBase 走单帧精灵通道装配

var _timer := 0.0
var _behavior: Dictionary = {}


func _on_planted() -> void:
	_behavior = GameConfig.PLANT_BEHAVIOR.get(plant_id, {})
	_timer = float(_behavior.get("first_fire", 0.8))


## 单局快照：投掷计时器
func snapshot_state() -> Dictionary:
	return {"t": _timer}


func restore_state(data: Dictionary) -> void:
	_timer = float(data.get("t", _timer))


func _tick(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if not _has_target():
		return
	_timer = float(_behavior.get("fire_interval", 3.0))
	_throw()


## 同行前方是否存在可命中僵尸（与射手类判定一致）
func _has_target() -> bool:
	for zombie in game.zombies_in_lane(cell.y):
		if zombie.can_be_hit() and zombie.position.x > position.x:
			return true
	return false


func _throw() -> void:
	game.spawn_melon(cell.y,
			Vector2(position.x + 30.0, GameConfig.cell_center_y(cell.y)),
			int(_behavior.get("damage", 80)),
			int(_behavior.get("splash_damage", 40)),
			bool(_behavior.get("slow", true)))