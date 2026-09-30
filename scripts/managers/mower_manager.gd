class_name MowerManager
extends Node2D
## 小推车管理：每行一台，僵尸抵达触发线时启动；已用掉的推车不再提供保护

var game: MainGameManager = null
var mowers: Array[LawnMower] = []


func setup(game_ref: MainGameManager) -> void:
	game = game_ref
	for lane in GameConfig.ROWS:
		var mower := LawnMower.new()
		mower.setup(lane, game)
		mowers.append(mower)
		game.mowers_root.add_child(mower)


func trigger_lane(lane: int) -> void:
	for mower in mowers:
		if mower == null or not is_instance_valid(mower):
			continue
		if mower.lane == lane and not mower.used:
			mower.trigger()
			return


func is_lane_protected(lane: int) -> bool:
	for mower in mowers:
		if mower == null or not is_instance_valid(mower):
			continue
		if mower.lane == lane and not mower.used:
			return true
	return false


# ---------------- 单局快照 ----------------
## 单局快照：每行一条（已用 / 冲出中 / 当前横坐标）
func to_snapshot() -> Dictionary:
	var data: Array = []
	for mower in mowers:
		if mower != null and is_instance_valid(mower):
			data.append(mower.to_snapshot())
	return {"mowers": data}


## 读档恢复：按行套用存档（缺行的行回退到初始状态，保证每行仍有推车数据）
func apply_snapshot(data: Dictionary) -> void:
	var by_row := {}
	var raw: Variant = data.get("mowers", [])
	if raw is Array:
		for entry in raw as Array:
			if entry is Dictionary:
				by_row[int((entry as Dictionary).get("row", -1))] = entry
	for mower in mowers:
		if mower == null or not is_instance_valid(mower):
			continue
		if by_row.has(mower.lane):
			mower.apply_snapshot(by_row[mower.lane] as Dictionary)
		else:
			mower.apply_snapshot({
				"row": mower.lane, "used": false, "running": false, "x": GameConfig.MOWER_X,
			})