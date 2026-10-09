extends Node
## 临时校验脚本（非游戏代码）：实体层单元校验
## 覆盖：7 种僵尸（顶具剥离 / 破损外观 / 减速 / 死亡 / 烧焦 / 无视顶具直杀）、
##       13 种植物实例化与扣费铲除、食人花吞噬、倭瓜压扁、土豆雷武装引爆、
##       樱桃 3×3、辣椒整行烧焦、寒冰减速、西瓜投手直伤与溅射、阳光收集飞行动画、
##       撑杆僵尸翻越、读报僵尸撕报提速、甜菜穿透弹
## 用法：godot --headless --fixed-fps 60 --quit-after 2400 --path <proj> res://tools/entity_test.tscn

const ZOMBIE_IDS: Array = ["basic", "cone", "bucket", "football", "door", "flag", "pole"]

const PLANT_CLASSES: Dictionary = {
	"sunflower": "PlantSunflower",
	"peashooter": "PlantShooter",
	"wallnut": "PlantWallnut",
	"cherrybomb": "PlantBomb",
	"repeater": "PlantShooter",
	"jalapeno": "PlantBomb",
	"snowpea": "PlantShooter",
	"threepeater": "PlantShooter",
	"squash": "PlantSquash",
	"chomper": "PlantChomper",
	"potato_mine": "PlantPotatoMine",
	"melonpult": "PlantMelonPult",
	"beetroot": "PlantBeetroot",
}

var game: MainGameManager = null

var _elapsed := 0.0
var _schedule: Array[Dictionary] = []
var _passed := 0
var _failed := 0
var _failures: Array[String] = []
var _refs: Dictionary = {}


func _ready() -> void:
	game = MainGameManager.new()
	add_child(game)
	# 测试期隔离：跳过波次投放，并让 all_spawned 永不成立（避免自动胜利中断用例）
	game.wave_manager.wave_index = GameConfig.WAVES.size()
	game.wave_manager._pending.append({"t": 1.0e9, "type": "basic"})
	game.add_sun(10000)
	_schedule = [
		{"t": 0.1, "cb": _stage_zombie_matrix},
		{"t": 0.5, "cb": _stage_plant_matrix},
		{"t": 2.5, "cb": _stage_behavior_start},
		{"t": 4.0, "cb": _stage_chomper_check},
		{"t": 4.2, "cb": _stage_cherry_check},
		{"t": 5.5, "cb": _stage_squash_check},
		{"t": 6.0, "cb": _stage_shooter_check},
		{"t": 6.2, "cb": _stage_melon_place},
		{"t": 9.5, "cb": _stage_melon_check},
		{"t": 19.0, "cb": _stage_mine_spawn},
		{"t": 21.0, "cb": _stage_mine_check},
		{"t": 21.5, "cb": _stage_jalapeno_place},
		{"t": 24.0, "cb": _stage_jalapeno_check},
		{"t": 24.5, "cb": _stage_snowpea_place},
		{"t": 28.0, "cb": _stage_snowpea_check},
		{"t": 29.0, "cb": _stage_sun_fly_start},
		{"t": 29.8, "cb": _stage_sun_fly_check},
		{"t": 30.5, "cb": _stage_new_entities},
		{"t": 31.2, "cb": _stage_final},
	]
	print("[TEST] 实体层校验开始（波次已隔离）")


func _process(delta: float) -> void:
	if game == null or _schedule.is_empty():
		return
	_elapsed += delta
	while not _schedule.is_empty() and _elapsed >= float(_schedule[0]["t"]):
		var entry: Dictionary = _schedule.pop_front()
		(entry["cb"] as Callable).call()


# ---------------- 断言工具 ----------------
func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("[PASS] ", label)
		return
	_failed += 1
	_failures.append(label)
	print("[FAIL] ", label)


func _class_of(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return "<null>"
	return String(node.get_script().get_global_name())


func _spawn(zombie_id: String, lane: int, x: float) -> ZombieBase:
	var zombie := ZombieFactory.create(zombie_id)
	zombie.setup(zombie_id, lane, x, game)
	game.wave_manager.zombies.append(zombie)
	game.zombies_root.add_child(zombie)
	return zombie


func _is_gone(raw: Variant) -> bool:
	if raw == null or not is_instance_valid(raw):
		return true
	var zombie := raw as ZombieBase
	return zombie.state == ZombieBase.E_State.Dying or zombie.state == ZombieBase.E_State.Burnt


func _state_of(raw: Variant) -> String:
	if raw == null or not is_instance_valid(raw):
		return "已销毁"
	return "状态%d" % (raw as ZombieBase).state


func _hp_of(raw: Variant) -> int:
	if raw == null or not is_instance_valid(raw):
		return -1
	return (raw as ZombieBase).hp


func _is_slowed(raw: Variant) -> bool:
	if raw == null or not is_instance_valid(raw):
		return false
	var zombie := raw as ZombieBase
	return zombie._slow_timer > 0.0 and zombie.sprite.modulate == ZombieBase.FROZEN_TINT


## 用例收尾：移除本轮探针僵尸，避免继续前进破坏后续用例（如啃掉土豆地雷）
func _despawn(raw: Variant) -> void:
	if raw != null and is_instance_valid(raw):
		(raw as Node).queue_free()


# ---------------- 用例 ----------------
func _stage_zombie_matrix() -> void:
	print("[TEST] --- 僵尸矩阵 ---")
	for raw_id in ZOMBIE_IDS:
		var zombie_id := String(raw_id)
		var data := GameConfig.zombie_data(zombie_id)
		var probe := _spawn(zombie_id, 0, 1500.0)
		_check("%s 生命=%d 速度=%.0f" % [zombie_id, probe.max_hp, probe.base_speed],
				probe.max_hp == int(data["hp"]) and probe.base_speed == float(data["speed"]))
		var hat_hp := int(data.get("hat_hp", 0))
		if hat_hp > 0:
			_check("%s 初始顶具生命=%d" % [zombie_id, hat_hp],
					probe.has_hat and probe.hat_hp == hat_hp)
			probe.take_damage(hat_hp)
			_check("%s 顶具剥离且本体无损" % zombie_id,
					not probe.has_hat and probe.hp == probe.max_hp)
			_check("%s 剥离后外观=%s" % [zombie_id, probe._current_anim()],
					probe._current_anim() == "bare_walk")
			if data.has("hat_removed_speed"):
				_check("%s 剥离后减速为 %.0f" % [zombie_id, float(data["hat_removed_speed"])],
						is_equal_approx(probe.current_speed(), float(data["hat_removed_speed"])))
		var walk_speed := probe.current_speed()
		probe.apply_slow()
		_check("%s 寒冰减速后速度减半（%.1f→%.1f）" % [zombie_id, walk_speed, probe.current_speed()],
				is_equal_approx(probe.current_speed(), walk_speed * GameConfig.SLOW_FACTOR))
		_check("%s 减速染色生效" % zombie_id, probe.sprite.modulate == ZombieBase.FROZEN_TINT)
		probe.take_damage(999999)
		_check("%s 生命归零进入死亡态" % zombie_id,
				probe.state == ZombieBase.E_State.Dying and probe.hp <= 0)
		probe.free()

	# 破损外观（普通僵尸血量低于 dirt_ratio 后切换失头外观）
	var dirty := _spawn("basic", 0, 1500.0)
	dirty.hp = int(float(dirty.max_hp) * 0.4)
	dirty._sync_anim()
	_check("basic 残血外观=%s" % dirty._current_anim(), dirty._current_anim() == "dirty_walk")
	dirty.free()

	# 烧焦
	var burnt := _spawn("bucket", 0, 1500.0)
	burnt.burn()
	_check("bucket 烧焦状态与动画=%s" % burnt.sprite.animation,
			burnt.state == ZombieBase.E_State.Burnt and burnt.sprite.animation == &"burnt")
	burnt.free()

	# 直接致死无视顶具（食人花 / 小推车）
	var eaten := _spawn("cone", 0, 1500.0)
	eaten.kill_directly()
	_check("cone 直杀无视顶具（顶具仍在=%s 状态=%d）" % [str(eaten.has_hat), eaten.state],
			eaten.state == ZombieBase.E_State.Dying and eaten.has_hat)
	eaten.free()


func _stage_plant_matrix() -> void:
	print("[TEST] --- 植物矩阵 ---")
	var cells: Array[Vector2i] = []
	for row in GameConfig.ROWS:
		cells.append(Vector2i(8, row))
		cells.append(Vector2i(7, row))
	cells.append(Vector2i(6, 0))
	cells.append(Vector2i(6, 1))
	cells.append(Vector2i(6, 2))
	var index := 0
	for raw_id in GameConfig.PLANT_ORDER:
		var plant_id := String(raw_id)
		var cell: Vector2i = cells[index]
		index += 1
		var before := game.sun
		var ok := game.grid_manager.place_plant(plant_id, cell)
		var plant := game.grid_manager.plant_at(cell)
		_check("%s 种植于 %s 且扣费 %d" % [plant_id, str(cell), GameConfig.plant_cost(plant_id)],
				ok and before - game.sun == GameConfig.plant_cost(plant_id))
		_check("%s 实体类=%s" % [plant_id, _class_of(plant)],
				_class_of(plant) == String(PLANT_CLASSES[plant_id]))
		_check("%s 生命=%d 卡片冷却=%.1fs" % [plant_id, GameConfig.plant_data(plant_id)["hp"],
				GameConfig.plant_recharge(plant_id)],
				plant != null and plant.max_hp == int(GameConfig.plant_data(plant_id)["hp"]) \
				and GameConfig.plant_recharge(plant_id) > 0.0)

	# 同格重复种植必须被拦截且不扣费
	var occupied := Vector2i(8, 0)
	var sun_before := game.sun
	_check("同格重复种植被拦截",
			not game.grid_manager.place_plant("peashooter", occupied) and game.sun == sun_before)
	# 越界格子必须被拦截
	_check("越界格子被拦截",
			not game.grid_manager.place_plant("peashooter", Vector2i(GameConfig.COLS, 0)))

	# 铲除
	game.grid_manager.is_shovel_mode = true
	var shovel_ok := game.grid_manager.try_shovel_at(GameConfig.cell_center(occupied))
	game.grid_manager.is_shovel_mode = false
	_check("铲除后格子释放", shovel_ok and game.grid_manager.is_free(occupied))


func _stage_behavior_start() -> void:
	print("[TEST] --- 植物行为 ---")
	# 豌豆射手 → 受伤
	game.grid_manager.place_plant("peashooter", Vector2i(1, 0))
	_refs["shoot_target"] = _spawn("basic", 0, 1400.0)
	# 食人花 → 吞噬
	game.grid_manager.place_plant("chomper", Vector2i(3, 1))
	var chomper := game.grid_manager.plant_at(Vector2i(3, 1))
	_refs["chomper_pos"] = chomper.position.x
	_refs["chomper_target"] = _spawn("basic", 1, chomper.position.x + 40.0)
	# 倭瓜 → 压扁
	game.grid_manager.place_plant("squash", Vector2i(3, 2))
	var squash := game.grid_manager.plant_at(Vector2i(3, 2))
	_refs["squash_target"] = _spawn("basic", 2, squash.position.x + 100.0)
	# 土豆地雷 → 武装后引爆
	game.grid_manager.place_plant("potato_mine", Vector2i(3, 3))
	var mine := game.grid_manager.plant_at(Vector2i(3, 3))
	_refs["mine_pos"] = mine.position.x
	# 樱桃炸弹 → 3×3
	game.grid_manager.place_plant("cherrybomb", Vector2i(4, 4))
	_refs["cherry_group"] = [
		_spawn("basic", 4, GameConfig.cell_center(Vector2i(3, 4)).x),
		_spawn("basic", 4, GameConfig.cell_center(Vector2i(4, 4)).x),
		_spawn("basic", 4, GameConfig.cell_center(Vector2i(5, 4)).x),
	]


func _stage_chomper_check() -> void:
	_check("食人花吞噬前方僵尸（%s）" % _state_of(_refs["chomper_target"]),
			_is_gone(_refs["chomper_target"]))


func _stage_cherry_check() -> void:
	var all_dead := true
	for raw in _refs["cherry_group"]:
		if not _is_gone(raw):
			all_dead = false
	_check("樱桃炸弹 3×3 范围清场", all_dead)
	_check("樱桃炸弹引爆后自身消失", game.grid_manager.is_free(Vector2i(4, 4)))


func _stage_squash_check() -> void:
	_check("倭瓜跃起压扁僵尸（%s）" % _state_of(_refs["squash_target"]),
			_is_gone(_refs["squash_target"]))
	_check("倭瓜压扁后自身消失", game.grid_manager.is_free(Vector2i(3, 2)))


func _stage_shooter_check() -> void:
	var raw: Variant = _refs["shoot_target"]
	var current: int = -1
	if raw != null and is_instance_valid(raw):
		current = (raw as ZombieBase).hp
	_check("豌豆射手命中僵尸（剩余生命=%d/200）" % current, current > 0 and current < 200)


func _stage_melon_place() -> void:
	print("[TEST] --- 西瓜投手 ---")
	game.grid_manager.place_plant("melonpult", Vector2i(1, 2))
	_refs["melon_plant"] = game.grid_manager.plant_at(Vector2i(1, 2))
	# 同一 x 上摆放相邻三行僵尸：中间行为直击目标，上下两行验证溅射
	_refs["melon_group"] = [
		_spawn("basic", 1, 1300.0),
		_spawn("basic", 2, 1300.0),
		_spawn("basic", 3, 1300.0),
	]


func _stage_melon_check() -> void:
	var direct_damage := int(GameConfig.PLANT_BEHAVIOR["melonpult"]["damage"])
	var splash_damage := int(GameConfig.PLANT_BEHAVIOR["melonpult"]["splash_damage"])
	var group: Array = _refs["melon_group"]
	var direct: Variant = group[1]
	var above: Variant = group[0]
	var below: Variant = group[2]
	_check("西瓜直击僵尸（剩余生命=%d/200）" % _hp_of(direct),
			_hp_of(direct) == 200 - direct_damage)
	_check("西瓜溅射命中上一行（剩余生命=%d/200）" % _hp_of(above),
			_hp_of(above) == 200 - splash_damage)
	_check("西瓜溅射命中下一行（剩余生命=%d/200）" % _hp_of(below),
			_hp_of(below) == 200 - splash_damage)
	_check("西瓜命中后直击目标进入减速", _is_slowed(direct))
	_check("西瓜溅射目标同样进入减速", _is_slowed(above) and _is_slowed(below))
	var plant: Variant = _refs.get("melon_plant")
	_check("西瓜投手本体使用静态单图（单帧 main 动画）",
			plant != null and is_instance_valid(plant) \
			and (plant as PlantBase).sprite.sprite_frames.has_animation("main") \
			and (plant as PlantBase).sprite.sprite_frames.get_frame_count("main") == 1)
	for zombie in group:
		_despawn(zombie)


func _stage_mine_spawn() -> void:
	var mine := game.grid_manager.plant_at(Vector2i(3, 3))
	_check("土豆地雷武装后动画=%s" % str(mine.sprite.animation if mine != null else "<null>"),
			mine != null and str(mine.sprite.animation) == "armed")
	_refs["mine_target"] = _spawn("basic", 3, float(_refs["mine_pos"]) + 50.0)


func _stage_mine_check() -> void:
	_check("土豆地雷引爆僵尸（%s）" % _state_of(_refs["mine_target"]),
			_is_gone(_refs["mine_target"]))
	_check("土豆地雷引爆后自身消失", game.grid_manager.is_free(Vector2i(3, 3)))


func _stage_jalapeno_place() -> void:
	game.grid_manager.place_plant("jalapeno", Vector2i(4, 0))
	_refs["burn_group"] = [
		_spawn("bucket", 0, 1200.0),
		_spawn("cone", 0, 1500.0),
	]


func _stage_jalapeno_check() -> void:
	var all_burnt := true
	for raw in _refs["burn_group"]:
		if not _is_gone(raw):
			all_burnt = false
	_check("火爆辣椒烧焦整行僵尸（含顶具）", all_burnt)


func _stage_snowpea_place() -> void:
	game.grid_manager.place_plant("snowpea", Vector2i(2, 4))
	_refs["slow_target"] = _spawn("bucket", 4, 1300.0)


func _stage_snowpea_check() -> void:
	var raw: Variant = _refs["slow_target"]
	var slowed := false
	if raw != null and is_instance_valid(raw):
		slowed = (raw as ZombieBase)._slow_timer > 0.0 \
				and (raw as ZombieBase).sprite.modulate == ZombieBase.FROZEN_TINT
	_check("寒冰射手命中后僵尸进入减速（%s）" % _state_of(raw), slowed)


func _stage_sun_fly_start() -> void:
	print("[TEST] --- 阳光收集飞行动画 ---")
	game.spawn_sun(Vector2(900.0, 600.0), GameConfig.SUNFLOWER_SUN_VALUE, "plant")
	var sun: SunItem = game.sun_manager.suns.back()
	_refs["sun_fly_node"] = sun
	_refs["sun_fly_before"] = game.sun
	_refs["sun_fly_value"] = sun.value
	var hit := game.sun_manager.try_collect_at(sun.global_position)
	_check("点击命中阳光并进入飞行动画", hit and is_instance_valid(sun))
	_check("飞行途中阳光数不提前增加", game.sun == int(_refs["sun_fly_before"]))


func _stage_sun_fly_check() -> void:
	var raw: Variant = _refs.get("sun_fly_node")
	var expected: int = int(_refs["sun_fly_before"]) + int(_refs["sun_fly_value"])
	_check("飞抵计数框后阳光入账", game.sun == expected)
	_check("飞抵计数框后阳光节点销毁", raw == null or not is_instance_valid(raw))


# ---------------- 新增植物 / 僵尸 ----------------
func _stage_new_entities() -> void:
	print("[TEST] --- 新增植物 / 僵尸 ---")
	_stage_beetroot()
	_stage_pole_vault()
	_stage_newspaper_rip()


## 甜菜：沿本行发射穿透弹，命中后弹体继续前进
func _stage_beetroot() -> void:
	var beet_cell := Vector2i(1, 3)
	game.grid_manager.place_plant("beetroot", beet_cell)
	var beet: PlantBase = game.grid_manager.plant_at(beet_cell)
	_check("甜菜实体类=PlantBeetroot", _class_of(beet) == "PlantBeetroot")
	if beet == null:
		return
	var beet_x := GameConfig.cell_center(beet_cell).x
	var front := _spawn("basic", 3, beet_x + 220.0)
	var rear := _spawn("basic", 3, beet_x + 420.0)
	var front_hp := front.hp
	var rear_hp := rear.hp
	beet._tick(10.0)
	var bullet: BeetBullet = null
	for node in game.bullets_root.get_children():
		if node is BeetBullet:
			bullet = node as BeetBullet
	_check("甜菜开火生成穿透弹", bullet != null)
	if bullet != null:
		for _i in 80:
			bullet._process(0.05)
		_check("甜菜弹命中前排僵尸", front.hp < front_hp)
		_check("甜菜弹穿透后排僵尸", rear.hp < rear_hp)
		_check("甜菜弹穿透后仍在飞行", is_instance_valid(bullet))
		if is_instance_valid(bullet):
			bullet.free()
	_despawn(front)
	_despawn(rear)


## 撑杆僵尸：前方出现植物即起跳，落点恰好前移一格
func _stage_pole_vault() -> void:
	var wall_cell := Vector2i(4, 1)
	game.grid_manager.place_plant("wallnut", wall_cell)
	var wall_x := GameConfig.cell_center(wall_cell).x
	var pole := ZombiePole.new()
	pole.setup("pole", 1, wall_x + 100.0, game)
	game.zombies_root.add_child(pole)
	pole._tick_walk(0.016)
	_check("撑杆僵尸遇植物起跳", pole._vaulted and pole._jumping)
	var from_x := pole.position.x
	pole._tick_jump(GameConfig.POLE_VAULT_TIME)
	_check("撑杆僵尸翻越一格（%.0f→%.0f）" % [from_x, pole.position.x],
			not pole._jumping
			and is_equal_approx(pole.position.x, from_x - GameConfig.POLE_VAULT_DISTANCE))
	pole.free()


## 读报僵尸：报纸被撕后僵直播放撕裂动画，播完换无报纸外观并提速
func _stage_newspaper_rip() -> void:
	var paper := ZombieNewspaper.new()
	paper.setup("newspaper", 0, 1500.0, game)
	game.zombies_root.add_child(paper)
	var walk_speed := paper.current_speed()
	paper.take_damage(paper.hat_hp)
	_check("读报僵尸报纸被撕后进入僵直", paper._ripping and paper._current_anim() == "rip")
	paper._on_rip_finished()
	_check("读报僵尸撕报结束后提速（%.0f→%.0f）" % [walk_speed, paper.current_speed()],
			not paper._ripping and not paper.has_hat and paper.current_speed() > walk_speed)
	paper.free()


func _stage_final() -> void:
	print("[TEST] ================= 汇总 =================")
	print("[TEST] 通过 %d 项，失败 %d 项" % [_passed, _failed])
	for label in _failures:
		print("[TEST] 失败项：", label)
	print("[TEST] 场上存活僵尸=%d 已种植=%d 阳光=%d 游戏结束=%s" % [
		game.wave_manager.alive_count(), game.grid_manager.occupied_count(),
		game.sun, str(game.is_over)])
	_schedule.clear()
	get_tree().quit()