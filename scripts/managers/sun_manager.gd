class_name SunManager
extends Node2D
## 阳光经济：天降阳光定时投放、阳光收集判定、失效引用清理

var game: MainGameManager = null
var suns: Array[SunItem] = []

var _sky_timer := 0.0


func setup(game_ref: MainGameManager) -> void:
	game = game_ref
	_sky_timer = GameConfig.SKY_SUN_FIRST


## 清空场上全部阳光（读档重建时使用；阳光属瞬态对象，不入档）
func clear_suns() -> void:
	for sun in suns:
		if sun != null and is_instance_valid(sun):
			sun.queue_free()
	suns = []


# ---------------- 单局快照 ----------------
## 单局快照：仅天降阳光计时器（场上阳光不入档）
func to_snapshot() -> Dictionary:
	return {"sky_sun_timer": _sky_timer}


## 读档恢复：还原天降计时器并清空残留阳光
func apply_snapshot(data: Dictionary) -> void:
	_sky_timer = float(data.get("sky_sun_timer", GameConfig.SKY_SUN_FIRST))
	clear_suns()


func _process(delta: float) -> void:
	if game == null or not game.is_running():
		return
	_sky_timer -= delta
	if _sky_timer > 0.0:
		return
	_sky_timer = GameConfig.SKY_SUN_INTERVAL
	# 夜间关卡不天降阳光（GameConfig.NIGHT_SKY_SUN_ENABLED 可放开）
	if game.is_night() and not GameConfig.NIGHT_SKY_SUN_ENABLED:
		return
	_spawn_sky_sun()


func _spawn_sky_sun() -> void:
	var spawn_x := randf_range(GameConfig.GRID_X - 60.0, GameConfig.CANVAS_W - 160.0)
	var target_y := randf_range(260.0, 960.0)
	game.spawn_sun(Vector2(spawn_x, -70.0), GameConfig.SKY_SUN_VALUE, "sky", target_y)


func register(sun: SunItem) -> void:
	suns.append(sun)


## 点击收集：命中最近的一颗阳光
func try_collect_at(world_pos: Vector2) -> bool:
	var best: SunItem = null
	var best_distance := SunItem.COLLECT_RADIUS
	for index in range(suns.size() - 1, -1, -1):
		var sun := suns[index]
		if sun == null or not is_instance_valid(sun):
			suns.remove_at(index)
			continue
		var distance := sun.global_position.distance_to(world_pos)
		if distance <= best_distance:
			best = sun
			best_distance = distance
	if best == null:
		return false
	best.collect()
	return true