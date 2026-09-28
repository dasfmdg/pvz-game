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