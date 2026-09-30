class_name WaveManager
extends Node2D
## 波次调度：按时间表投放僵尸（同波内错峰出场），大波追加旗帜僵尸与横幅
## 加速规则：本波僵尸被提前全灭时，不再等时间表到点，随机等 3~7s 就进入下一波

var game: MainGameManager = null
var zombies: Array[ZombieBase] = []
var all_spawned := false
var wave_index := 0

var _elapsed := 0.0
var _pending: Array[Dictionary] = []
var _lane_cursor := 0
## 提前清空后下一波的触发时刻（<0 表示未触发加速）
var _early_trigger_at := -1.0


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
	_update_early_trigger()
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
	while wave_index < game.level_waves.size():
		var wave: Dictionary = game.level_waves[wave_index]
		if _elapsed < _wave_due_time(wave):
			return
		_launch_wave(wave_index, wave)
		wave_index += 1
		_early_trigger_at = -1.0


## 本波出场时刻：到点必出；若上一波已被提前清空，则取更早的加速时刻
func _wave_due_time(wave: Dictionary) -> float:
	var scheduled := float(wave["t"])
	if _early_trigger_at < 0.0:
		return scheduled
	return minf(scheduled, _early_trigger_at)


## 场上已无存活僵尸且当前波已全部出场时，安排一次 3~7s 后的提前出波
func _update_early_trigger() -> void:
	if wave_index <= 0 or wave_index >= game.level_waves.size():
		return
	if not _pending.is_empty() or alive_count() > 0:
		return
	if _early_trigger_at < 0.0:
		_early_trigger_at = _elapsed + randf_range(
				GameConfig.WAVE_EARLY_MIN, GameConfig.WAVE_EARLY_MAX)


func _launch_wave(index: int, wave: Dictionary) -> void:
	var is_huge := bool(wave.get("huge", false))
	var types: Array = (wave["z"] as Array).duplicate()
	if is_huge:
		types.push_front("flag")
		game.play_sfx("zombies_are_coming")
	EventBus.wave_started.emit(index + 1, game.total_waves(), is_huge)
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
	if all_spawned or wave_index < game.level_waves.size() or not _pending.is_empty():
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