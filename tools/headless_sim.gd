extends Node
## 临时校验脚本（非游戏代码）：headless 下模拟玩家完整对局
## 覆盖：阳光生成与采集、11 种植物、波次投放、僵尸受伤/顶具/减速、小推车、胜负判定
## 用法：godot --headless --fixed-fps 60 --quit-after N --path <proj> res://tools/headless_sim.tscn

const BUILD_ORDER: Array = [
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

var game: MainGameManager = null

var _cursor := 0
var _collect_timer := 0.0
var _report_timer := 0.0
var _last_time := 0.0
var _plants_placed := 0
var _sun_collected := 0
var _kills := 0
var _burnt := 0
var _waves := 0
var _huge := 0
var _breaches := 0
var _bullet_peak := 0
var _result := ""


func _ready() -> void:
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.zombie_died.connect(_on_zombie_died)
	EventBus.zombie_breached.connect(_on_breached)
	EventBus.all_waves_spawned.connect(_on_all_spawned)
	EventBus.game_over.connect(_on_game_over)
	game = MainGameManager.new()
	add_child(game)
	print("[SIM] 启动：初始阳光=", game.sun, " 卡片数=", GameConfig.PLANT_ORDER.size())


func _process(delta: float) -> void:
	if game == null:
		return
	_last_time += delta
	_collect_timer -= delta
	if _collect_timer <= 0.0:
		_collect_timer = 0.5
		_collect_suns()
	_try_build()
	_bullet_peak = maxi(_bullet_peak, game.bullets_root.get_child_count())
	_report_timer -= delta
	if _report_timer <= 0.0:
		_report_timer = 10.0
		_print_status()
		if _last_time >= 420.0 and _result.is_empty():
			_finish("超时未结束")
		if _last_time >= 480.0:
			get_tree().quit()


func _collect_suns() -> void:
	for child in game.suns_root.get_children():
		var sun_item := child as SunItem
		if sun_item == null or not is_instance_valid(sun_item):
			continue
		if game.sun_manager.try_collect_at(sun_item.global_position):
			_sun_collected += 1


func _try_build() -> void:
	while _cursor < BUILD_ORDER.size():
		var entry: Dictionary = BUILD_ORDER[_cursor]
		var cell: Vector2i = entry["cell"]
		var plant_id: String = entry["id"]
		if not game.grid_manager.is_free(cell):
			_cursor += 1
			continue
		if game.sun < GameConfig.plant_cost(plant_id):
			return
		if game.grid_manager.place_plant(plant_id, cell):
			_plants_placed += 1
		_cursor += 1


func _print_status() -> void:
	print("[SIM] t=%.1f sun=%d 种植=%d/%d 击杀=%d 烧焦=%d 存活=%d 波次=%d/%d 大波=%d 破防=%d 子弹峰值=%d 阳光采集=%d" % [
		_last_time, game.sun, _plants_placed, BUILD_ORDER.size(), _kills, _burnt,
		game.wave_manager.alive_count(), _waves, GameConfig.WAVES.size(), _huge,
		_breaches, _bullet_peak, _sun_collected])


func _finish(reason: String) -> void:
	if not _result.is_empty():
		return
	_result = reason
	print("[SIM] === 对局结论：", reason, " ===")
	_print_status()
	var alive := game.wave_manager.alive_count()
	print("[SIM] 校验：击杀+烧焦=%d 存活=%d 结束=%s 胜利=%s" % [
		_kills + _burnt, alive, str(game.is_over), str(_result.begins_with("胜利"))])
	# 复核：所有波次是否都已投放
	print("[SIM] 全部波次已投放=", game.wave_manager.all_spawned, " 波次进度=",
		game.wave_manager.wave_index, "/", GameConfig.WAVES.size())


func _on_wave_started(index: int, total: int, is_huge: bool) -> void:
	_waves = index
	if is_huge:
		_huge += 1
	print("[SIM] 波次 %d/%d 开始，大波=%s，场上存活=%d" % [
		index, total, str(is_huge), game.wave_manager.alive_count()])


func _on_zombie_died(_lane: int, was_burnt: bool) -> void:
	if was_burnt:
		_burnt += 1
	else:
		_kills += 1


func _on_breached(lane: int) -> void:
	_breaches += 1
	print("[SIM] 僵尸破防 lane=%d t=%.1f 该行推车保护=%s" % [
		lane, _last_time, str(game.mower_manager.is_lane_protected(lane))])


func _on_all_spawned() -> void:
	print("[SIM] 全部波次已投放 t=%.1f" % _last_time)


func _on_game_over(is_win: bool, killed: int) -> void:
	_finish("胜利" if is_win else "失败")
	print("[SIM] game_over 事件 killed=%d" % killed)