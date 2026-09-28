class_name MainGameManager
extends Node2D
## 主控：装配世界层与子系统、阳光经济、统一输入路由、胜负判定
## 参考工程对应：scripts/manager/main_game_manager.gd（子管理器装配 + 统一调度）

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


func _ready() -> void:
	_create_layers()
	_create_subsystems()
	sun = GameConfig.START_SUN
	EventBus.sun_changed.emit(sun)
	SoundManager.play_bgm()


func _create_layers() -> void:
	var background := SpriteLibrary.make_static_sprite("lawn",
			GameConfig.CANVAS_W, GameConfig.CANVAS_H)
	background.position = Vector2(GameConfig.CANVAS_W * 0.5, GameConfig.CANVAS_H * 0.5)
	background.z_index = -100
	add_child(background)

	plants_root = _make_layer("PlantsRoot", 10)
	mowers_root = _make_layer("MowersRoot", 15)
	zombies_root = _make_layer("ZombiesRoot", 20)
	bullets_root = _make_layer("BulletsRoot", 30)
	fx_root = _make_layer("FxRoot", 40)
	suns_root = _make_layer("SunsRoot", 50)


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
				get_tree().reload_current_scene()
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