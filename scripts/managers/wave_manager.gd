class_name WaveManager
extends Node2D
## 波次调度：按时间表投放僵尸（同波内错峰出场），大波追加旗帜僵尸与横幅

var game: MainGameManager = null
var zombies: Array[ZombieBase] = []
var all_spawned := false
var wave_index := 0

var _elapsed := 0.0
var _pending: Array[Dictionary] = []
var _lane_cursor := 0


func setup(game_ref: MainGameManager) -> void:
	game = game_ref
	_lane_cursor = randi_range(0, GameConfig.ROWS - 1)


func level_time() -> float:
	return _elapsed


func _process(delta: float) -> void:
	if game == null or not game.is_running():
		return
	_elapsed += delta
	_launch_due_waves()
	_release_pending()
	_prune()
	if all_spawned and alive_count() == 0:
		all_spawned = false
		game.on_all_zombies_cleared()


# ---------------- 查询 ----------------
func zombies_in_lane(lane: int) -> Array[ZombieBase]:
	var result: Array[ZombieBase] = []
	for zombie in zombies:
		if zombie == null or not is_instance_valid(zombie):
			continue
		if zombie.lane != lane or not zombie.can_be_hit():
			continue
		result.append(zombie)
	return result


func all_zombies() -> Array[ZombieBase]:
	var result: Array[ZombieBase] = []
	for zombie in zombies:
		if zombie != null and is_instance_valid(zombie):
			result.append(zombie)
	return result


func alive_count() -> int:
	var count := 0
	for zombie in zombies:
		if zombie != null and is_instance_valid(zombie) and zombie.can_be_hit():
			count += 1
	return count


# ---------------- 投放 ----------------
func _launch_due_waves() -> void:
	while wave_index < GameConfig.WAVES.size():
		var wave: Dictionary = GameConfig.WAVES[wave_index]
		if _elapsed < float(wave["t"]):
			return
		_launch_wave(wave_index, wave)
		wave_index += 1


func _launch_wave(index: int, wave: Dictionary) -> void:
	var is_huge := bool(wave.get("huge", false))
	var types: Array = (wave["z"] as Array).duplicate()
	if is_huge:
		types.push_front("flag")
		game.play_sfx("zombies_are_coming")
	EventBus.wave_started.emit(index + 1, GameConfig.WAVES.size(), is_huge)
	for i in types.size():
		_pending.append({
			"t": _elapsed + float(i) * GameConfig.WAVE_UNIT_GAP,
			"type": String(types[i]),
		})


func _release_pending() -> void:
	if _pending.is_empty():
		_check_all_spawned()
		return
	var remaining: Array[Dictionary] = []
	for entry in _pending:
		if _elapsed >= float(entry["t"]):
			_spawn_zombie(String(entry["type"]))
		else:
			remaining.append(entry)
	_pending = remaining
	_check_all_spawned()


func _check_all_spawned() -> void:
	if all_spawned or wave_index < GameConfig.WAVES.size() or not _pending.is_empty():
		return
	all_spawned = true
	EventBus.all_waves_spawned.emit()


func _spawn_zombie(zombie_id: String) -> void:
	var zombie := ZombieBase.new()
	zombie.setup(zombie_id, _next_lane(),
			GameConfig.ZOMBIE_SPAWN_X + randf_range(0.0, 140.0), game)
	zombies.append(zombie)
	game.zombies_root.add_child(zombie)


## 轮转选行（步长 1~2），避免同波僵尸全部挤在同一行
func _next_lane() -> int:
	_lane_cursor = (_lane_cursor + randi_range(1, 2)) % GameConfig.ROWS
	return _lane_cursor


func _prune() -> void:
	var kept: Array[ZombieBase] = []
	for zombie in zombies:
		if zombie != null and is_instance_valid(zombie):
			kept.append(zombie)
	zombies = kept