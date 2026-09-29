extends Node
## 临时校验脚本（非游戏代码）：30 关逐关自动布阵模拟
## 目的 1（链路体检）：每关都必须打到胜利 / 失败，不允许卡死超时
## 目的 2（难度读数）：用接近真人的布阵策略——补种被啃掉的植物、僵尸扎堆时主动丢瞬发植物、
##                      按当前关卡解锁进度自动降级替代植物，让胜负数字具备参考意义
## 用法：godot --headless --fixed-fps 60 --path <proj> res://tools/level_sim.tscn
## 说明：不改动任何游戏代码。注意 GridManager.place_plant 不校验卡片冷却，因此本模拟不体现
##       冷却等待（真人会有冷却空窗），读数整体偏乐观。

## 布阵顺序（列优先，列号越大越靠近僵尸）：先铺经济，再铺火力，最后补防线
## 每格的首选植物不可用时按 FALLBACK 降级，仍未解锁则跳过该格
## 夜间关卡不天降阳光，经济只能靠向日葵，因此经济列加倍、火力列减一层
const SUNFLOWER_COLS_DAY: Array[int] = [0]
const SUNFLOWER_COLS_NIGHT: Array[int] = [0, 1]
const SHOOTER_COLS_DAY: Array[int] = [1, 2, 3]
const SHOOTER_COLS_NIGHT: Array[int] = [2, 3]
const WALLNUT_COL := 6

## 火力格的首选顺序（从左到右依次降级，取第一个已解锁的）
const SHOOTER_FALLBACK: Array[Array] = [
	["repeater", "peashooter"],
	["snowpea", "repeater", "peashooter"],
	["threepeater", "repeater", "peashooter"],
]

## 瞬发植物使用阈值：单路活僵尸数达到该值就丢（樱桃先于辣椒，辣椒留给更拥挤的路）
const CHERRY_CROWD := 4
const JALAPENO_CROWD := 7

## 超时余量：不能只按「出生点→小推车 1360px / 24px每秒 ≈ 57 秒」估算——
## 僵尸还会停下来啃植物，坚果 4000 血 / 68 血每秒 ≈ 59 秒一个，寒冰减速后再翻倍，
## 最后一波僵尸实际耗时常超过 150 秒，因此取 400 秒，并由 _check_stalls 单独兜真卡死
const TIMEOUT_MARGIN := 400.0

## 真停滞判定：Walk 状态僵尸的 x 连续这么久不下降即为「走不动」，
## 与「走得慢 / 正在啃食」区分开（啃食状态 x 本来就不变，不计入）
const STALL_SECONDS := 20.0
const STALL_CHECK_INTERVAL := 1.0
const COLLECT_INTERVAL := 0.5
const LEVEL_GAP := 0.25

var _index := -1
var _game: MainGameManager = null
var _elapsed := 0.0
var _timeout := 0.0
var _jobs: Array = []
var _collect_timer := 0.0
var _gap := 0.0
var _win := false
var _results: Array[String] = []
var _failures: Array[String] = []
var _stalls: Array[String] = []
var _stall_watch: Dictionary = {}
var _stall_timer := 0.0


func _ready() -> void:
	EventBus.game_over.connect(_on_game_over)
	Engine.time_scale = 3.0
	print("[LEVELSIM] 开始：共 %d 关，time_scale=%.1f" % [
		GameConfig.LEVELS.size(), Engine.time_scale])
	_next_level()


func _process(delta: float) -> void:
	if _gap > 0.0:
		_gap -= delta
		return
	if _game == null:
		return
	_elapsed += delta
	_collect_timer -= delta
	if _collect_timer <= 0.0:
		_collect_timer = COLLECT_INTERVAL
		_collect_suns()
	_stall_timer -= delta
	if _stall_timer <= 0.0:
		_stall_timer = STALL_CHECK_INTERVAL
		_check_stalls()
	_try_build()
	if _game.is_over:
		_finish_level(false)
	elif _elapsed >= _timeout:
		_finish_level(true)


# ---------------- 关卡切换 ----------------
func _next_level() -> void:
	_index += 1
	if _index >= GameConfig.LEVELS.size():
		_report()
		get_tree().quit()
		return
	var level: Dictionary = GameConfig.LEVELS[_index]
	var waves: Array = level["waves"]
	var last_wave: Dictionary = waves[waves.size() - 1]

	_game = MainGameManager.new()
	_game.setup_level(_index)
	add_child(_game)

	_elapsed = 0.0
	_collect_timer = 0.0
	_win = false
	_stall_watch = {}
	_stall_timer = 0.0
	_timeout = float(last_wave["t"]) + TIMEOUT_MARGIN
	_jobs = _make_jobs()
	print("[LEVELSIM] --- 第 %d 关 %s（%s / 难度 %d / 阳光 %d / 波次 %d / 卡片 %d / 计划 %d 格）---" % [
		_index + 1, String(level["name"]),
		"夜" if _game.is_night() else "昼",
		int(level["difficulty"]), int(level["start_sun"]),
		waves.size(), _game.level_plants.size(), _jobs.size()])


func _finish_level(timed_out: bool) -> void:
	var wave_manager := _game.wave_manager
	var spawned: int = wave_manager.wave_index
	var total: int = _game.total_waves()
	var verdict := "超时未结束" if timed_out else ("胜利" if _win else "失败")
	var summary := "第 %d 关 %s：%s，击杀 %d，波次 %d/%d，存活 %d，场上植物 %d" % [
		_index + 1, String(GameConfig.LEVELS[_index]["name"]), verdict,
		_game.killed, spawned, total, wave_manager.alive_count(),
		_game.grid_manager.occupied_count()]
	_results.append(summary)
	if timed_out:
		_failures.append("第 %d 关超时未结束（波次 %d/%d）" % [_index + 1, spawned, total])
		_dump_survivors()
	elif _win and spawned < total:
		_failures.append("第 %d 关判胜但波次未投放完（%d/%d）" % [_index + 1, spawned, total])
	print("[LEVELSIM] ", summary)

	_game.queue_free()
	_game = null
	_gap = LEVEL_GAP
	_next_level()


## 超时取证：打印仍可被攻击的残留僵尸，用于判断是「打不到」还是「打不死」
func _dump_survivors() -> void:
	for zombie in _game.wave_manager.all_zombies():
		if zombie == null or not is_instance_valid(zombie):
			continue
		if not zombie.can_be_hit():
			print("[LEVELSIM]   残留（不可攻击）id=%s 路=%d x=%.1f 状态=%d" % [
				zombie.zombie_id, zombie.lane, zombie.position.x, zombie.state])
			continue
		var bite := zombie.position.x - ZombieBase.BITE_OFFSET
		var plant := _game.grid_manager.find_eatable_plant(zombie.lane, bite)
		print("[LEVELSIM]   残留 id=%s 路=%d x=%.1f 状态=%d hp=%d 顶具=%s 速度=%.1f 啃食目标=%s" % [
			zombie.zombie_id, zombie.lane, zombie.position.x, zombie.state, zombie.hp,
			"有" if zombie.has_hat else "无", zombie.current_speed(),
			"无" if plant == null else String(plant.plant_id)])


## 真卡死取证：行走中的僵尸若 x 长时间不下降，说明不是「走得慢」而是「走不动」，
## 与超时（走得慢）互为交叉验证；每只僵尸只报一次
func _check_stalls() -> void:
	for zombie in _game.wave_manager.all_zombies():
		if zombie == null or not is_instance_valid(zombie) or not zombie.can_be_hit():
			continue
		var key := zombie.get_instance_id()
		if zombie.state != ZombieBase.E_State.Walk:
			_stall_watch.erase(key)
			continue
		var entry: Dictionary = _stall_watch.get(key, {})
		var last_x := float(entry.get("x", zombie.position.x))
		var held := float(entry.get("held", 0.0))
		var reported := bool(entry.get("reported", false))
		held = (held + STALL_CHECK_INTERVAL) if absf(zombie.position.x - last_x) < 0.5 else 0.0
		if held >= STALL_SECONDS and not reported:
			reported = true
			var note := "第 %d 关僵尸停滞：%s 路=%d x=%.1f hp=%d 顶具=%s 速度=%.1f 持续 %.0f 秒" % [
				_index + 1, zombie.zombie_id, zombie.lane, zombie.position.x, zombie.hp,
				"有" if zombie.has_hat else "无", zombie.current_speed(), held]
			_stalls.append(note)
			print("[LEVELSIM]   !! 停滞告警 ", note)
		_stall_watch[key] = {"x": zombie.position.x, "held": held, "reported": reported}


# ---------------- 布阵计划 ----------------
## 按本关已解锁卡片与昼夜生成布阵计划：经济 → 火力 → 防线；未解锁的格直接跳过
func _make_jobs() -> Array:
	var night := _game.is_night()
	var sunflower_cols: Array[int] = SUNFLOWER_COLS_NIGHT if night else SUNFLOWER_COLS_DAY
	var shooter_cols: Array[int] = SHOOTER_COLS_NIGHT if night else SHOOTER_COLS_DAY
	var jobs: Array = []
	for col in sunflower_cols:
		for row in GameConfig.ROWS:
			_add_job(jobs, "sunflower", col, row)
	var layers: int = mini(shooter_cols.size(), SHOOTER_FALLBACK.size())
	for layer in layers:
		var fallback: Array = SHOOTER_FALLBACK[layer]
		for row in GameConfig.ROWS:
			_add_job(jobs, _pick_unlocked(fallback), shooter_cols[layer], row)
	for row in GameConfig.ROWS:
		_add_job(jobs, "wallnut", WALLNUT_COL, row)
	return jobs


func _add_job(jobs: Array, plant_id: String, col: int, row: int) -> void:
	if plant_id.is_empty() or not _game.level_plants.has(plant_id):
		return
	jobs.append({"id": plant_id, "cell": Vector2i(col, row)})


## 取首选顺序里第一个本关已解锁的植物；全未解锁返回空串
func _pick_unlocked(fallback: Array) -> String:
	for plant_id in fallback:
		if _game.level_plants.has(plant_id):
			return String(plant_id)
	return ""


# ---------------- 模拟玩家行为 ----------------
func _collect_suns() -> void:
	for child in _game.suns_root.get_children():
		var sun_item := child as SunItem
		if sun_item == null or not is_instance_valid(sun_item):
			continue
		_game.sun_manager.try_collect_at(sun_item.global_position)


func _try_build() -> void:
	if _try_reactive_instant():
		return
	_try_next_job()


## 按计划顺序补种：格子空着且买得起就种一株；已被啃掉的格子会被重新补上（顺序优先）
func _try_next_job() -> void:
	for job in _jobs:
		var plant_id := String(job["id"])
		var cell: Vector2i = job["cell"]
		if not _game.grid_manager.is_free(cell):
			continue
		if _game.sun < GameConfig.plant_cost(plant_id):
			continue
		if _game.grid_manager.place_plant(plant_id, cell):
			return


## 反应式瞬发：单路僵尸扎堆时丢樱桃 / 辣椒，种在僵尸行进路线前方
func _try_reactive_instant() -> bool:
	var lane := _crowded_lane()
	if lane < 0:
		return false
	var plant_id := ""
	if _crowded_count(lane) >= JALAPENO_CROWD and _game.level_plants.has("jalapeno"):
		plant_id = "jalapeno"
	elif _crowded_count(lane) >= CHERRY_CROWD and _game.level_plants.has("cherrybomb"):
		plant_id = "cherrybomb"
	if plant_id.is_empty():
		return false
	if _game.sun < GameConfig.plant_cost(plant_id):
		return false
	var cell := _front_cell_of(lane)
	if not GameConfig.is_valid_cell(cell):
		return false
	return _game.grid_manager.place_plant(plant_id, cell)


## 活僵尸最多的路；无僵尸返回 -1
func _crowded_lane() -> int:
	var best_lane := -1
	var best_count := 0
	for lane in GameConfig.ROWS:
		var count := _crowded_count(lane)
		if count > best_count:
			best_count = count
			best_lane = lane
	return best_lane


func _crowded_count(lane: int) -> int:
	var count := 0
	for zombie in _game.zombies_in_lane(lane):
		if zombie.can_be_hit():
			count += 1
	return count


## 该路最靠左（最靠近房子）的活僵尸所在格，再往前推一格作为瞬发落点；
## 前方越界或被占用则退回僵尸所在格；都不可用返回 (-1, -1)
func _front_cell_of(lane: int) -> Vector2i:
	var min_x := INF
	for zombie in _game.zombies_in_lane(lane):
		if zombie.can_be_hit():
			min_x = minf(min_x, zombie.position.x)
	if min_x == INF:
		return Vector2i(-1, -1)
	var zombie_cell := GameConfig.point_to_cell(Vector2(min_x, 0.0))
	var ahead := Vector2i(zombie_cell.x + 1, lane)
	if GameConfig.is_valid_cell(ahead) and _game.grid_manager.is_free(ahead):
		return ahead
	var here := Vector2i(zombie_cell.x, lane)
	if GameConfig.is_valid_cell(here) and _game.grid_manager.is_free(here):
		return here
	return Vector2i(-1, -1)


func _on_game_over(is_win: bool, _killed: int) -> void:
	_win = is_win


# ---------------- 汇总 ----------------
func _report() -> void:
	var wins := 0
	for line in _results:
		if line.contains("胜利"):
			wins += 1
	print("[LEVELSIM] ================= 汇总 =================")
	for line in _results:
		print("[LEVELSIM] ", line)
	print("[LEVELSIM] 关数=%d 胜利=%d 非胜利=%d 异常=%d 真停滞=%d" % [
		_results.size(), wins, _results.size() - wins, _failures.size(), _stalls.size()])
	for label in _failures:
		print("[LEVELSIM] 异常项：", label)
	for note in _stalls:
		print("[LEVELSIM] 停滞项：", note)