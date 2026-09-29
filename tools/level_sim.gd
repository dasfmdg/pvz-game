extends Node
## 临时校验脚本（非游戏代码）：30 关逐关自动布阵模拟
## 覆盖：逐关装载关卡数据（波次 / 初始阳光 / 按 unlockLevel 生成的卡片）、自动采集阳光与布阵、
##       波次投放与胜负链路（每关都应打到胜利 / 失败，不允许卡死超时）
## 用法：godot --headless --fixed-fps 60 --path <proj> res://tools/level_sim.tscn
## 说明：不改动任何游戏代码；超时阈值 = 本关最后一波时间 + TIMEOUT_MARGIN

## 与 headless_sim.gd 相同的布阵顺序；本关未解锁的植物自动跳过
const BUILD_PLAN: Array = [
	{"cell": Vector2i(0, 0), "id": "sunflower"},
	{"cell": Vector2i(0, 1), "id": "sunflower"},
	{"cell": Vector2i(0, 2), "id": "sunflower"},
	{"cell": Vector2i(0, 3), "id": "sunflower"},
	{"cell": Vector2i(0, 4), "id": "sunflower"},
	{"cell": Vector2i(1, 0), "id": "peashooter"},
	{"cell": Vector2i(1, 1), "id": "peashooter"},
	{"cell": Vector2i(1, 2), "id": "peashooter"},
	{"cell": Vector2i(1, 3), "id": "peashooter"},
	{"cell": Vector2i(1, 4), "id": "peashooter"},
	{"cell": Vector2i(2, 1), "id": "snowpea"},
	{"cell": Vector2i(2, 2), "id": "repeater"},
	{"cell": Vector2i(2, 3), "id": "threepeater"},
	{"cell": Vector2i(3, 0), "id": "potato_mine"},
	{"cell": Vector2i(3, 1), "id": "squash"},
	{"cell": Vector2i(3, 2), "id": "chomper"},
	{"cell": Vector2i(4, 3), "id": "cherrybomb"},
	{"cell": Vector2i(4, 4), "id": "jalapeno"},
	{"cell": Vector2i(6, 0), "id": "wallnut"},
	{"cell": Vector2i(6, 1), "id": "wallnut"},
	{"cell": Vector2i(6, 2), "id": "wallnut"},
	{"cell": Vector2i(6, 3), "id": "wallnut"},
	{"cell": Vector2i(6, 4), "id": "wallnut"},
]

## 超时余量：须覆盖最后一波僵尸走到小推车的时间（出生点→触发点约 1360px / 26px每秒 ≈ 53 秒）
## 再留出啃食植物的时间，取 150 秒；若仍超时说明对局链路真的卡住了
const TIMEOUT_MARGIN := 150.0
const COLLECT_INTERVAL := 0.5
const LEVEL_GAP := 0.25

var _index := -1
var _game: MainGameManager = null
var _elapsed := 0.0
var _timeout := 0.0
var _cursor := 0
var _collect_timer := 0.0
var _gap := 0.0
var _win := false
var _results: Array[String] = []
var _failures: Array[String] = []


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
	_cursor = 0
	_collect_timer = 0.0
	_win = false
	_timeout = float(last_wave["t"]) + TIMEOUT_MARGIN
	print("[LEVELSIM] --- 第 %d 关 %s（%s / 难度 %d / 阳光 %d / 波次 %d / 卡片 %d）---" % [
		_index + 1, String(level["name"]),
		"夜" if _game.is_night() else "昼",
		int(level["difficulty"]), int(level["start_sun"]),
		waves.size(), _game.level_plants.size()])


func _finish_level(timed_out: bool) -> void:
	var wave_manager := _game.wave_manager
	var spawned: int = wave_manager.wave_index
	var total: int = _game.total_waves()
	var verdict := "超时未结束" if timed_out else ("胜利" if _win else "失败")
	var summary := "第 %d 关 %s：%s，击杀 %d，波次 %d/%d，存活 %d" % [
		_index + 1, String(GameConfig.LEVELS[_index]["name"]), verdict,
		_game.killed, spawned, total, wave_manager.alive_count()]
	_results.append(summary)
	if timed_out:
		_failures.append("第 %d 关超时未结束（波次 %d/%d）" % [_index + 1, spawned, total])
	elif _win and spawned < total:
		_failures.append("第 %d 关判胜但波次未投放完（%d/%d）" % [_index + 1, spawned, total])
	print("[LEVELSIM] ", summary)

	_game.queue_free()
	_game = null
	_gap = LEVEL_GAP
	_next_level()


# ---------------- 模拟玩家行为 ----------------
func _collect_suns() -> void:
	for child in _game.suns_root.get_children():
		var sun_item := child as SunItem
		if sun_item == null or not is_instance_valid(sun_item):
			continue
		_game.sun_manager.try_collect_at(sun_item.global_position)


func _try_build() -> void:
	var plants: Array = _game.level_plants
	while _cursor < BUILD_PLAN.size():
		var entry: Dictionary = BUILD_PLAN[_cursor]
		var plant_id := String(entry["id"])
		if not plants.has(plant_id):
			_cursor += 1
			continue
		var cell: Vector2i = entry["cell"]
		if not _game.grid_manager.is_free(cell):
			_cursor += 1
			continue
		if _game.sun < GameConfig.plant_cost(plant_id):
			return
		if not _game.grid_manager.place_plant(plant_id, cell):
			_cursor += 1
			continue
		_cursor += 1


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
	print("[LEVELSIM] 关数=%d 胜利=%d 非胜利=%d 异常=%d" % [
		_results.size(), wins, _results.size() - wins, _failures.size()])
	for label in _failures:
		print("[LEVELSIM] 异常项：", label)