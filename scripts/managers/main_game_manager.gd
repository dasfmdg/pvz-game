class_name MainGameManager
extends Node2D
## 主控：装配世界层与子系统、阳光经济、统一输入路由、胜负判定
## 参考工程对应：scripts/manager/main_game_manager.gd（子管理器装配 + 统一调度）

## 关卡结算需要重开时发出（由界面路由接管重载关卡）
signal restart_requested()
## 请求读取单局快照（由 HUD 发出，由界面路由接管「重建关卡 + 覆盖状态」）
signal load_run_requested(slot: int)

## 单局快照结构版本（与 SaveManager.RUN_SAVE_VERSION 对应）
const SNAPSHOT_VERSION := 1
## 读档必备字段：任一缺失即判定为不可用快照
const SNAPSHOT_REQUIRED_FIELDS: Array[String] = [
	"level_index", "level_plants", "time", "sun", "killed",
	"wave", "plants", "zombies", "mowers",
]

var plants_root: Node2D = null
var mowers_root: Node2D = null
var zombies_root: Node2D = null
var bullets_root: Node2D = null
var fx_root: Node2D = null
var suns_root: Node2D = null

var grid_manager: GridManager = null
var sun_manager: SunManager = null
var wave_manager: WaveManager = null
var mower_manager: MowerManager = null
var hud: GameHud = null

var sun := 0
var killed := 0
var is_paused := false
var is_over := false

## 当前关卡数据：默认第 1 关（与既有回归行为完全一致）
var level_index := 0
var level_waves: Array = GameConfig.WAVES
var level_plants: Array = GameConfig.PLANT_ORDER
var level_start_sun := GameConfig.START_SUN
## 当前关卡场景（day / night），默认白天，保证未装载关卡数据的回归行为不变
var level_scene := GameConfig.SCENE_DAY


## 载入关卡数据（须在加入场景树前调用；index 越界自动钳制）
## selected_plants 为空表示「沿用解锁表」，保证 level_sim 等旧调用路径行为不变
func setup_level(index: int, selected_plants: Array = []) -> void:
	level_index = clampi(index, 0, GameConfig.LEVELS.size() - 1)
	var data: Dictionary = GameConfig.LEVELS[level_index]
	level_waves = data["waves"]
	level_plants = _resolve_level_plants(selected_plants)
	level_start_sun = int(data["start_sun"])
	level_scene = String(data.get("scene", GameConfig.SCENE_DAY))


## 本关实际携带的卡片：越权 / 重复 / 超额一律丢弃，净化后为空则回退全量，绝不出现零张卡
func _resolve_level_plants(selected_plants: Array) -> Array:
	var unlocked := GameConfig.plants_for_level(level_index + 1)
	if selected_plants.is_empty():
		return unlocked
	var limit := GameConfig.seed_slot_limit(level_index + 1)
	var result: Array[String] = []
	for raw_id in selected_plants:
		if result.size() >= limit:
			break
		var plant_id := String(raw_id)
		if unlocked.has(plant_id) and not result.has(plant_id):
			result.append(plant_id)
	if result.is_empty():
		return unlocked
	return result


## 当前是否为夜间关卡
func is_night() -> bool:
	return level_scene == GameConfig.SCENE_NIGHT


## 当前关卡总波数
func total_waves() -> int:
	return level_waves.size()


func _ready() -> void:
	_create_layers()
	_create_subsystems()
	sun = level_start_sun
	EventBus.sun_changed.emit(sun)
	SoundManager.play_bgm()


func _create_layers() -> void:
	var background := _make_lawn_background()
	background.name = "LawnBackground"
	background.position = Vector2(GameConfig.CANVAS_W * 0.5, GameConfig.CANVAS_H * 0.5)
	background.z_index = -100
	add_child(background)

	plants_root = _make_layer("PlantsRoot", 10)
	mowers_root = _make_layer("MowersRoot", 15)
	zombies_root = _make_layer("ZombiesRoot", 20)
	bullets_root = _make_layer("BulletsRoot", 30)
	fx_root = _make_layer("FxRoot", 40)
	suns_root = _make_layer("SunsRoot", 50)


## 草坪背景：夜间关卡优先用夜景素材，素材缺失时回退白天草坪 + 冷色调
## 冷色调只作用于背景贴图，不压暗实体与界面
func _make_lawn_background() -> Sprite2D:
	if not is_night():
		return SpriteLibrary.make_static_sprite("lawn",
				GameConfig.CANVAS_W, GameConfig.CANVAS_H)
	var night_tex: Texture2D = null
	if ResourceLoader.exists(GameConfig.NIGHT_LAWN_PATH):
		night_tex = SpriteLibrary.texture(GameConfig.NIGHT_LAWN_PATH)
	if night_tex == null:
		var fallback := SpriteLibrary.make_static_sprite("lawn",
				GameConfig.CANVAS_W, GameConfig.CANVAS_H)
		fallback.modulate = GameConfig.NIGHT_LAWN_TINT
		return fallback
	var sprite := Sprite2D.new()
	sprite.texture = night_tex
	var tex_size := night_tex.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		sprite.scale = Vector2(GameConfig.CANVAS_W / tex_size.x,
				GameConfig.CANVAS_H / tex_size.y)
	return sprite


func _make_layer(layer_name: String, layer_z: int) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.z_index = layer_z
	add_child(layer)
	return layer


func _create_subsystems() -> void:
	grid_manager = GridManager.new()
	grid_manager.setup(self)
	add_child(grid_manager)

	sun_manager = SunManager.new()
	sun_manager.setup(self)
	add_child(sun_manager)

	wave_manager = WaveManager.new()
	wave_manager.setup(self)
	add_child(wave_manager)

	mower_manager = MowerManager.new()
	mower_manager.setup(self)
	add_child(mower_manager)

	hud = GameHud.new()
	hud.setup(self)
	add_child(hud)


# ---------------- 输入路由（世界点击统一入口，避免多处争抢） ----------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_on_world_click(get_global_mouse_position())
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			_on_key_pressed(key)


func _on_world_click(world_pos: Vector2) -> void:
	if is_over:
		return
	if sun_manager.try_collect_at(world_pos):
		return
	if is_paused:
		return
	if grid_manager.try_plant_at(world_pos):
		return
	grid_manager.try_shovel_at(world_pos)


func _on_key_pressed(key: InputEventKey) -> void:
	match key.keycode:
		KEY_P:
			set_paused(not is_paused)
		KEY_M:
			SoundManager.toggle_mute()
		KEY_ESCAPE:
			grid_manager.clear_selection()
		KEY_R:
			if is_over:
				restart_requested.emit()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0:
			if hud != null:
				hud.select_card_by_key(key.keycode)


# ---------------- 供实体调用的对外接口 ----------------
func is_running() -> bool:
	return not is_paused and not is_over


func play_sfx(sound: String) -> void:
	SoundManager.play(sound)


func zombies_in_lane(lane: int) -> Array[ZombieBase]:
	if wave_manager == null:
		return []
	return wave_manager.zombies_in_lane(lane)


func spawn_bullet(lane: int, pos_x: float, pos_y: float, damage: int, is_ice: bool) -> void:
	var bullet := PeaBullet.new()
	bullet.setup(lane, Vector2(pos_x, pos_y), damage, is_ice, self)
	bullets_root.add_child(bullet)


## 西瓜投手弹道：直线飞行 + 命中溅射，弹体自带视觉弧线
func spawn_melon(lane: int, pos: Vector2, damage: int, splash_damage: int, slows: bool) -> void:
	var melon := MelonBullet.new()
	melon.setup(lane, pos, damage, splash_damage, slows, self)
	bullets_root.add_child(melon)


## 甜菜弹道：穿透整行，可依次命中同一行的多个僵尸
func spawn_beet_bullet(lane: int, pos_x: float, pos_y: float, damage: int) -> void:
	var beet := BeetBullet.new()
	beet.setup(lane, Vector2(pos_x, pos_y), damage, self)
	bullets_root.add_child(beet)


func spawn_sun(pos: Vector2, value: int, kind: String, target_y := -1.0) -> void:
	var sun_item := SunItem.new()
	var sun_kind := SunItem.E_Kind.Sky if kind == "sky" else SunItem.E_Kind.Plant
	sun_item.setup(value, sun_kind, target_y if target_y >= 0.0 else pos.y, self)
	sun_item.position = pos
	suns_root.add_child(sun_item)
	sun_manager.register(sun_item)


func spawn_fx(sheet: String, pos: Vector2, draw_size: float, speed_scale := 1.0) -> void:
	Fx.spawn(fx_root, sheet, pos, draw_size, speed_scale)


## 3×3 范围伤害（以格子为单位）
func explode_area(center_cell: Vector2i, radius_cells: int, damage: int) -> void:
	for zombie in wave_manager.all_zombies():
		if not zombie.can_be_hit():
			continue
		var cell := GameConfig.point_to_cell(zombie.position)
		if absi(cell.x - center_cell.x) <= radius_cells \
				and absi(cell.y - center_cell.y) <= radius_cells:
			zombie.take_damage(damage)


func damage_zombies_near(pos: Vector2, radius: float, damage: int) -> void:
	for zombie in wave_manager.all_zombies():
		if not zombie.can_be_hit():
			continue
		if zombie.position.distance_to(pos) <= radius:
			zombie.take_damage(damage)


## 整行烧毁（火爆辣椒）
func burn_lane(lane: int, _damage: int) -> void:
	for zombie in wave_manager.zombies_in_lane(lane):
		zombie.burn()


func add_sun(value: int) -> void:
	sun += value
	EventBus.sun_changed.emit(sun)
	EventBus.sun_collected.emit(value)


func try_spend_sun(cost: int) -> bool:
	if sun < cost:
		return false
	sun -= cost
	EventBus.sun_changed.emit(sun)
	return true


# ---------------- 进程控制 ----------------
func on_zombie_killed() -> void:
	killed += 1


func on_zombie_breached(zombie: ZombieBase) -> void:
	if mower_manager.is_lane_protected(zombie.lane):
		return
	EventBus.zombie_breached.emit(zombie.lane)
	end_game(false)


func on_all_zombies_cleared() -> void:
	end_game(true)


func set_paused(paused: bool) -> void:
	if is_over:
		return
	is_paused = paused
	EventBus.game_paused.emit(is_paused)


func end_game(is_win: bool) -> void:
	if is_over:
		return
	is_over = true
	if is_win:
		SoundManager.play("brainz")
	EventBus.game_over.emit(is_win, killed)


# ---------------- 单局快照 ----------------
## 抓取当前单局状态快照（豌豆 / 阳光 / 爆炸特效等瞬态对象一律不入档）
func capture_snapshot() -> Dictionary:
	var sun_snap := sun_manager.to_snapshot()
	var wave_snap := wave_manager.to_snapshot()
	var grid_snap := grid_manager.to_snapshot()
	var mower_snap := mower_manager.to_snapshot()
	return {
		"version": SNAPSHOT_VERSION,
		"level_index": level_index,
		"level_plants": level_plants.duplicate(),
		"time": wave_manager.level_time(),
		"sun": sun,
		"killed": killed,
		"sky_sun_timer": float(sun_snap.get("sky_sun_timer", GameConfig.SKY_SUN_FIRST)),
		"wave": wave_snap,
		"card_cooldowns": _card_cooldowns_snapshot(),
		"plants": grid_snap.get("plants", []),
		"zombies": _zombies_snapshot(),
		"mowers": mower_snap.get("mowers", []),
	}


## 请求读取快照槽位（由 HUD 触发；真正重建关卡由界面路由接管）
func request_load(slot: int) -> void:
	load_run_requested.emit(slot)


## 覆盖式读档：清空重建后的植物 / 僵尸 / 小推车，再按快照还原状态
## 版本不匹配或关键字段缺失时返回 false 并告警，绝不改动当前局
func apply_snapshot(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != SNAPSHOT_VERSION:
		push_warning("[MainGameManager] 单局快照版本不兼容，忽略读档")
		return false
	if not _snapshot_fields_ok(data):
		push_warning("[MainGameManager] 单局快照关键字段缺失，忽略读档")
		return false

	# 先清空刚建出来的实体（瞬态弹道 / 特效一并清掉）
	grid_manager.clear_plants()
	wave_manager.clear_zombies()
	sun_manager.clear_suns()
	_clear_layer(bullets_root)
	_clear_layer(fx_root)

	is_over = false
	is_paused = false
	killed = maxi(0, int(data.get("killed", 0)))
	sun = maxi(0, int(data.get("sun", level_start_sun)))
	EventBus.sun_changed.emit(sun)

	# 先设定关卡时间，波次 pending 的相对剩余秒数依赖它还原为绝对时刻
	wave_manager.set_level_time(float(data.get("time", 0.0)))
	wave_manager.apply_snapshot(data.get("wave", {}) as Dictionary)
	sun_manager.apply_snapshot({
		"sky_sun_timer": data.get("sky_sun_timer", GameConfig.SKY_SUN_FIRST),
	})
	grid_manager.apply_snapshot({"plants": data.get("plants", [])})
	_apply_zombies(data.get("zombies", []))
	mower_manager.apply_snapshot({"mowers": data.get("mowers", [])})
	_apply_card_cooldowns(data.get("card_cooldowns", {}))
	return true


## 必备字段与类型校验
func _snapshot_fields_ok(data: Dictionary) -> bool:
	for key in SNAPSHOT_REQUIRED_FIELDS:
		if not data.has(key):
			return false
	return data["level_plants"] is Array and data["wave"] is Dictionary \
		and data["plants"] is Array and data["zombies"] is Array \
		and data["mowers"] is Array


## 各卡剩余冷却 {植物 id: 秒}
func _card_cooldowns_snapshot() -> Dictionary:
	if hud == null or hud.card_slot == null:
		return {}
	return hud.card_slot.to_snapshot()


func _apply_card_cooldowns(data: Variant) -> void:
	if hud == null or hud.card_slot == null:
		return
	var cooldowns: Dictionary = data as Dictionary if data is Dictionary else {}
	hud.card_slot.apply_snapshot(cooldowns)


## 场上僵尸快照：仅 Walk / Eat 入档（Dying / Burnt 属瞬态，跳过）
func _zombies_snapshot() -> Array:
	var data: Array = []
	for zombie in wave_manager.all_zombies():
		if zombie == null or not zombie.can_be_hit():
			continue
		data.append(zombie.to_snapshot())
	return data


## 按快照重建僵尸（类型非法 / 行越界一律丢弃）
func _apply_zombies(entries: Variant) -> void:
	if not (entries is Array):
		return
	for raw in entries as Array:
		if not (raw is Dictionary):
			continue
		var entry := raw as Dictionary
		var zombie_id := String(entry.get("type", ""))
		if not GameConfig.ZOMBIES.has(zombie_id):
			continue
		var lane := clampi(int(entry.get("row", 0)), 0, GameConfig.ROWS - 1)
		var zombie := ZombieBase.new()
		zombie.setup(zombie_id, lane, GameConfig.ZOMBIE_SPAWN_X, self)
		wave_manager.zombies.append(zombie)
		zombies_root.add_child(zombie)
		zombie.apply_snapshot(entry)


func _clear_layer(layer: Node2D) -> void:
	if layer == null:
		return
	for child in layer.get_children():
		child.queue_free()