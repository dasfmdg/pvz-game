extends Node
## 临时校验脚本（非游戏代码）：界面层与存档校验
## 覆盖：界面路由（菜单→关卡选择→进入/离开关卡）、存档往返与解锁、
##       关卡数据合法性、图鉴卡片数量、设置滑条与音量同步
## 用法：godot --headless --fixed-fps 60 --quit-after 3600 --path <proj> res://tools/screen_test.tscn

var _passed := 0
var _failed := 0
var _failures: Array[String] = []


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	_reset_save()
	await _test_router()
	await _test_save()
	_test_levels()
	await _test_almanac()
	await _test_settings()
	_report()


func _reset_save() -> void:
	SaveManager.cleared_levels.clear()
	SaveManager.best_kills = {}
	SaveManager.unlocked_level = 0
	SaveManager.save()


# ---------------- 断言工具 ----------------
func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("[PASS] ", label)
		return
	_failed += 1
	_failures.append(label)
	print("[FAIL] ", label)


# ---------------- 路由 ----------------
func _test_router() -> void:
	print("[TEST] --- 界面路由 ---")
	var scene := load("res://scenes/main.tscn") as PackedScene
	var router := scene.instantiate() as MainRouter
	add_child(router)
	await get_tree().process_frame

	_check("初始进入启动加载页",
			router.state == MainRouter.E_State.SPLASH and router.current_screen is SplashScreen)
	var splash := router.current_screen as SplashScreen
	_check("加载页封面贴图加载成功", splash != null and splash.has_cover_texture())
	if splash != null:
		splash.dismiss()
	await get_tree().process_frame
	_check("加载页确认后进入主菜单",
			router.state == MainRouter.E_State.MENU and router.current_screen is MenuScreen)
	_check("主菜单含 4 个按钮",
			router.current_screen is MenuScreen \
			and (router.current_screen as MenuScreen).buttons.size() == 4)
	_check("主菜单告示牌显示玩家名字",
			router.current_screen is MenuScreen \
			and (router.current_screen as MenuScreen).name_label != null \
			and (router.current_screen as MenuScreen).name_label.text == MenuScreen.PLAYER_NAME)

	router.show_level_select()
	await get_tree().process_frame
	_check("切换到关卡选择",
			router.state == MainRouter.E_State.LEVEL_SELECT \
			and router.current_screen is LevelSelectScreen)
	var select := router.current_screen as LevelSelectScreen
	_check("关卡选择含 30 个按钮",
			select != null and select.level_buttons.size() == GameConfig.LEVELS.size())
	var lock_consistent := true
	if select != null:
		for index in select.level_buttons.size():
			if select.level_buttons[index].disabled == SaveManager.is_unlocked(index):
				lock_consistent = false
	_check("锁定态与存档一致", lock_consistent)

	# 30 关卡片应为 5 列 × 6 行网格，整体不超出画布，且纵向需要滚动
	var col_step := LevelSelectScreen.CARD_W + LevelSelectScreen.CARD_GAP
	var row_step := LevelSelectScreen.CARD_H + LevelSelectScreen.CARD_GAP
	var grid_ok := select != null and select.level_buttons.size() == GameConfig.LEVELS.size()
	if grid_ok:
		var first: Button = select.level_buttons[0]
		var fifth: Button = select.level_buttons[4]
		var sixth: Button = select.level_buttons[5]
		var last: Button = select.level_buttons[29]
		grid_ok = is_equal_approx(first.size.x, LevelSelectScreen.CARD_W) \
			and is_equal_approx(fifth.global_position.x - first.global_position.x, 4.0 * col_step) \
			and is_equal_approx(sixth.global_position.y - first.global_position.y, row_step) \
			and is_equal_approx(last.global_position.x - first.global_position.x, 4.0 * col_step) \
			and is_equal_approx(last.global_position.y - first.global_position.y, 5.0 * row_step)
	_check("30 关卡片按 5 列 × 6 行排布", grid_ok)

	var scrollable := select != null and select.level_buttons.size() == GameConfig.LEVELS.size()
	if scrollable:
		var last_card_bottom: float = select.level_buttons[29].global_position.y \
			+ LevelSelectScreen.CARD_H
		var view_bottom := GameConfig.CANVAS_H - LevelSelectScreen.GRID_BOTTOM_MARGIN
		scrollable = last_card_bottom > view_bottom
	_check("关卡网格超出可视区（需要滚动）", scrollable)

	var inside_canvas := select != null
	if inside_canvas:
		for button in select.level_buttons:
			if button.global_position.x < 0.0 \
					or button.global_position.x + button.size.x > GameConfig.CANVAS_W:
				inside_canvas = false
	_check("卡片水平方向不超出画布", inside_canvas)

	router.start_level(0)
	await get_tree().process_frame
	_check("进入关卡后主控存在",
			router.game != null and router.game is MainGameManager)
	_check("主控已挂载到路由", router.game != null and router.game.get_parent() == router)
	_check("主控关卡数据为第 0 关", router.game != null and router.game.level_index == 0)
	_check("第 1 关卡片按解锁表生成",
			router.game != null \
			and router.game.level_plants.size() == GameConfig.plants_for_level(1).size())

	var game_ref: MainGameManager = router.game
	game_ref.end_game(true)
	await get_tree().process_frame
	_check("胜利后写入存档", SaveManager.best_kills.has(0))
	_check("结算遮罩出现", router.is_game_over_visible())
	_check("普通关卡不显示全通关画面", not router.is_final_win_visible())

	router.return_to_level_select()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("返回关卡选择",
			router.state == MainRouter.E_State.LEVEL_SELECT \
			and router.current_screen is LevelSelectScreen)
	_check("离开游戏态后主控被释放",
			router.game == null and not is_instance_valid(game_ref))

	router.start_level(15)
	await get_tree().process_frame
	_check("夜间关卡装载夜间场景",
			router.game != null and router.game.is_night())
	_check("夜间关卡卡片与解锁表一致",
			router.game != null \
			and router.game.level_plants.size() == GameConfig.plants_for_level(16).size())
	router.return_to_level_select()
	await get_tree().process_frame
	await get_tree().process_frame

	# 最后一关胜利应显示专属全通关结算画面
	router.start_level(GameConfig.LEVELS.size() - 1)
	await get_tree().process_frame
	var final_game: MainGameManager = router.game
	if final_game != null:
		final_game.end_game(true)
	await get_tree().process_frame
	_check("最后一关胜利显示全通关画面",
			final_game != null and router.is_final_win_visible())
	_check("全通关画面叠加在结算遮罩之上",
			router.is_game_over_visible() and router.is_final_win_visible())
	var final_hud_hidden := final_game != null and final_game.hud != null \
		and not final_game.hud.is_plain_game_over_visible()
	_check("全通关时 HUD 普通结算文案让位", final_hud_hidden)
	router.return_to_level_select()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("离开游戏态后全通关画面隐藏", not router.is_final_win_visible())

	await _test_seed_select(router)

	router.queue_free()
	await get_tree().process_frame


# ---------------- 选卡界面路由 ----------------
func _test_seed_select(router: MainRouter) -> void:
	print("[TEST] --- 选卡界面 ---")

	# 第 1~6 关：点卡片仍直接进关
	router.show_level_select()
	await get_tree().process_frame
	(router.current_screen as LevelSelectScreen).level_chosen.emit(5)
	await get_tree().process_frame
	_check("第 6 关点卡片直接进关",
			router.state == MainRouter.E_State.GAME and router.game != null \
			and router.game.level_index == 5)
	router.return_to_level_select()
	await get_tree().process_frame
	await get_tree().process_frame

	# 第 7 关：进关前先出选卡界面
	router.show_level_select()
	await get_tree().process_frame
	(router.current_screen as LevelSelectScreen).level_chosen.emit(6)
	await get_tree().process_frame
	_check("第 7 关先进入选卡界面",
			router.state == MainRouter.E_State.SEED_SELECT \
			and router.current_screen is SeedSelectScreen)
	var seed7 := router.current_screen as SeedSelectScreen
	if seed7 == null:
		return
	_check("选卡界面关卡序号正确", seed7.level_index == 6)
	_check("选卡界面槽位上限与配置一致",
			seed7.slot_limit == GameConfig.seed_slot_limit(7))
	_check("选卡界面可选卡按解锁表",
			seed7.cards.size() == GameConfig.plants_for_level(7).size() \
			and seed7.available_plants.size() == seed7.cards.size())
	_check("选卡界面默认预选满槽", seed7.picked.size() == seed7.slot_limit)
	var level_kinds: Array[String] = GameConfig.zombies_for_level(6)
	_check("选卡界面僵尸种类与配置一致",
			seed7.zombies.size() == level_kinds.size() \
			and seed7.zombie_tiles.size() == level_kinds.size())
	_check("选卡界面提示计数同步",
			seed7.count_label != null \
			and seed7.count_label.text == "已选 %d / %d 张" % [seed7.picked.size(), seed7.slot_limit])
	_check("已选预览条与已选数量一致",
			seed7.picked_tiles.size() == seed7.picked.size())

	var first_plant: String = seed7.picked[0]
	_check("取消已选卡片",
			seed7.toggle_plant(first_plant) and not seed7.picked.has(first_plant))
	_check("取消后计数同步",
			seed7.count_label.text == "已选 %d / %d 张" % [seed7.picked.size(), seed7.slot_limit])
	_check("腾位后可重选",
			seed7.toggle_plant(first_plant) \
			and seed7.picked[seed7.picked.size() - 1] == first_plant)

	seed7.back_button.pressed.emit()
	await get_tree().process_frame
	_check("选卡界面返回关卡选择",
			router.state == MainRouter.E_State.LEVEL_SELECT \
			and router.current_screen is LevelSelectScreen)

	# 第 17 关：11 选 9，验证满槽拒绝与改选
	(router.current_screen as LevelSelectScreen).level_chosen.emit(16)
	await get_tree().process_frame
	_check("第 17 关进入选卡界面",
			router.current_screen is SeedSelectScreen \
			and (router.current_screen as SeedSelectScreen).level_index == 16)
	var seed17 := router.current_screen as SeedSelectScreen
	if seed17 == null:
		return
	_check("第 17 关槽位上限为 9", seed17.slot_limit == 9)
	_check("第 17 关可选 11 张卡", seed17.available_plants.size() == 11)
	_check("第 17 关默认预选 9 张", seed17.picked.size() == 9)
	var spare_plant := ""
	for plant_id in seed17.available_plants:
		if not seed17.picked.has(plant_id):
			spare_plant = plant_id
			break
	_check("满槽时拒绝追加",
			not spare_plant.is_empty() and not seed17.toggle_plant(spare_plant))
	_check("满槽拒绝后已选不变", seed17.picked.size() == 9)
	var dropped_plant: String = seed17.picked[0]
	seed17.toggle_plant(dropped_plant)
	_check("腾位后可改选未携带的植物",
			seed17.toggle_plant(spare_plant) and seed17.picked.has(spare_plant))

	var chosen: Array = seed17.picked.duplicate()
	seed17.start_button.pressed.emit()
	await get_tree().process_frame
	_check("选卡确认后进入关卡",
			router.state == MainRouter.E_State.GAME and router.game != null \
			and router.game.level_index == 16)
	var same_plants := router.game != null \
		and router.game.level_plants.size() == chosen.size()
	if same_plants:
		for plant_id in chosen:
			if not router.game.level_plants.has(plant_id):
				same_plants = false
	_check("关卡卡片与所选植物一致", same_plants)

	# 冷却表现：数值取自配置；冷却中不置灰、显示倒计时；冷却走完闪一次并恢复置灰判定
	var test_card: CardItem = null
	if router.game != null and router.game.hud != null \
			and router.game.hud.card_slot != null \
			and not router.game.hud.card_slot.cards.is_empty():
		test_card = router.game.hud.card_slot.cards[0]
	_check("卡片冷却数值与配置一致",
			test_card != null and is_equal_approx(test_card.recharge,
					GameConfig.plant_recharge(test_card.plant_id)))
	if test_card != null:
		_check("初始卡片已就绪且无倒计时",
				test_card.is_ready() and not test_card.is_timer_visible()
				and not test_card.is_flashing())
		test_card.start_cooldown()
		_check("使用后按配置进入冷却",
				not test_card.is_ready() and not test_card.can_use()
				and is_equal_approx(test_card.recharge_left(), test_card.recharge))
		_check("冷却中显示剩余秒数", test_card.is_timer_visible())
		test_card.set_affordable(false)
		_check("冷却中阳光不足不置灰", not test_card.shows_unaffordable())
		test_card.tick(test_card.recharge)
		_check("冷却走完恢复可用",
				test_card.is_ready() and not test_card.is_timer_visible())
		_check("冷却完毕闪一次", test_card.is_flashing())
		_check("冷却结束后阳光不足才置灰", test_card.shows_unaffordable())
		test_card.tick(CardItem.READY_FLASH_TIME)
		_check("闪烁播放完自动消失", not test_card.is_flashing())
		test_card.set_affordable(true)
		_check("阳光充足恢复原色", not test_card.shows_unaffordable() \
				and test_card.can_use())

	# 波次节奏：到点必出；本波被提前清空时按 3~7s 随机提前出下一波
	if router.game != null and router.game.wave_manager != null:
		var wm: WaveManager = router.game.wave_manager
		var waves: Array = router.game.level_waves
		_check("首波按难度时间表到点出场",
				is_equal_approx(wm._wave_due_time(waves[0]), float(waves[0]["t"])))
		if waves.size() > 1:
			var second_scheduled := float(waves[1]["t"])
			wm.wave_index = 1
			wm._elapsed = 10.0
			wm._early_trigger_at = -1.0
			wm._update_early_trigger()
			var early_gap := wm._early_trigger_at - wm._elapsed
			_check("本波被提前清空后随机等 3~7s",
					early_gap >= GameConfig.WAVE_EARLY_MIN \
					and early_gap <= GameConfig.WAVE_EARLY_MAX)
			_check("加速触发早于时间表",
					is_equal_approx(wm._wave_due_time(waves[1]),
							minf(second_scheduled, wm._early_trigger_at)))
			wm._early_trigger_at = second_scheduled + 5.0
			_check("时间表更早时不因加速推迟",
					is_equal_approx(wm._wave_due_time(waves[1]), second_scheduled))
			wm._elapsed = second_scheduled + 0.1
			wm._launch_due_waves()
			_check("投放后加速标记复位",
					wm._early_trigger_at < 0.0 and wm.wave_index == 2)
			# 本波尚未出完 / 场上仍有存活僵尸时都不允许提前出波
			wm._early_trigger_at = -1.0
			wm._pending.append({"t": 1.0e9, "type": "basic"})
			wm._update_early_trigger()
			_check("本波尚未出完时不触发加速", wm._early_trigger_at < 0.0)
			wm._pending.clear()
			var probe := ZombieBase.new()
			probe.setup("basic", 0, GameConfig.ZOMBIE_SPAWN_X, router.game)
			wm.zombies.append(probe)
			router.game.zombies_root.add_child(probe)
			wm._update_early_trigger()
			_check("场上有存活僵尸时不触发加速", wm._early_trigger_at < 0.0)
			wm.zombies.erase(probe)
			probe.queue_free()

	var recorded := router.current_seed_selection.size() == chosen.size()
	if recorded:
		for plant_id in chosen:
			if not router.current_seed_selection.has(plant_id):
				recorded = false
	_check("路由记录本次选卡结果", recorded)

	router.game.restart_requested.emit()
	await get_tree().process_frame
	_check("重试沿用上次选卡结果",
			router.game != null and router.game.level_index == 16 \
			and router.game.level_plants.size() == chosen.size())

	router.return_to_level_select()
	await get_tree().process_frame
	await get_tree().process_frame
	(router.current_screen as LevelSelectScreen).level_chosen.emit(16)
	await get_tree().process_frame
	var seed_again := router.current_screen as SeedSelectScreen
	_check("再次进入选卡界面预选上次结果",
			seed_again != null and seed_again.picked.size() == chosen.size() \
			and seed_again.picked.has(spare_plant))
	if seed_again != null:
		seed_again.back_button.pressed.emit()
	await get_tree().process_frame
	_check("选卡取消后不进入关卡",
			router.state == MainRouter.E_State.LEVEL_SELECT and router.game == null)


# ---------------- 存档 ----------------
func _test_save() -> void:
	print("[TEST] --- 存档管理 ---")
	SaveManager.set_setting("bgm_volume", 0.3)
	SaveManager.set_setting("sfx_volume", 0.5)
	SaveManager.save()
	SaveManager.bgm_volume = 0.9
	SaveManager.load_save()
	_check("音量往返一致",
			is_equal_approx(SaveManager.bgm_volume, 0.3) \
			and is_equal_approx(SaveManager.sfx_volume, 0.5))
	_check("音量同步到 SoundManager", is_equal_approx(SoundManager.bgm_volume, 0.3))
	_check("存档文件已生成", FileAccess.file_exists(SaveManager.SAVE_PATH))

	SaveManager.mark_cleared(0, 7)
	_check("通关解锁下一关", SaveManager.is_unlocked(1))
	_check("记录最佳击杀", SaveManager.best_kills_of(0) == 7)
	SaveManager.mark_cleared(0, 3)
	_check("最佳击杀取较大值", SaveManager.best_kills_of(0) == 7)
	SaveManager.best_kills = {0: 7, 1: 5}
	_check("累计击杀为各关最佳击杀之和", SaveManager.total_best_kills() == 12)
	_check("无记录时累计击杀为 0", SaveManager.best_kills_of(29) == 0)

	# 存档结构：v2 分区 + 分关进度表
	SaveManager.save()
	var root := _read_save_json()
	_check("存档带结构版本号",
			int(root.get("version", 0)) == SaveManager.SAVE_VERSION)
	var settings := _dict_of(root, "settings")
	var progress := _dict_of(root, "progress")
	var levels := _dict_of(progress, "levels")
	_check("设置与进度分区落盘",
			settings.has("bgm_volume") and progress.has("unlocked_level") \
			and not levels.is_empty())
	var level0 := _dict_of(levels, "0")
	_check("分关进度表记通关与最佳击杀",
			bool(level0.get("cleared", false)) and int(level0.get("best_kills", 0)) == 7)

	# 旧 v1 扁平存档：字段不丢，读取后自动升级为 v2
	var keep_bgm := SaveManager.bgm_volume
	var keep_sfx := SaveManager.sfx_volume
	var keep_muted := SaveManager.muted
	var keep_cleared := SaveManager.cleared_levels.duplicate()
	var keep_kills := SaveManager.best_kills.duplicate()
	var keep_unlocked := SaveManager.unlocked_level
	_write_save_json({
		"bgm_volume": 0.25, "sfx_volume": 0.75, "muted": true,
		"cleared_levels": [0, 2], "best_kills": {"0": 9, "2": 4},
		"unlocked_level": 3,
	})
	SaveManager.load_save()
	_check("旧存档设置迁移",
			is_equal_approx(SaveManager.bgm_volume, 0.25) \
			and is_equal_approx(SaveManager.sfx_volume, 0.75) and SaveManager.muted)
	_check("旧存档进度迁移",
			SaveManager.is_cleared(0) and SaveManager.is_cleared(2) \
			and SaveManager.best_kills_of(0) == 9 and SaveManager.best_kills_of(2) == 4 \
			and SaveManager.is_unlocked(3) and not SaveManager.is_unlocked(5))
	_check("旧存档读入后自动升级为 v2",
			int(_read_save_json().get("version", 0)) == SaveManager.SAVE_VERSION)

	SaveManager.bgm_volume = keep_bgm
	SaveManager.sfx_volume = keep_sfx
	SaveManager.muted = keep_muted
	SaveManager.cleared_levels = keep_cleared
	SaveManager.best_kills = keep_kills
	SaveManager.unlocked_level = keep_unlocked
	SaveManager.save()


## 读取存档 JSON（缺失或损坏时返回空字典）
func _read_save_json() -> Dictionary:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


## 按 v1 扁平结构写一份存档，用于校验版本迁移
func _write_save_json(data: Dictionary) -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## 取子字典（缺失或类型不符时返回空字典）
func _dict_of(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, null)
	if value is Dictionary:
		return value as Dictionary
	return {}


# ---------------- 关卡数据 ----------------
func _test_levels() -> void:
	print("[TEST] --- 关卡数据 ---")
	_check("关卡数量为 30", GameConfig.LEVELS.size() == 30)
	var night_count := 0
	for i in GameConfig.LEVELS.size():
		var level: Dictionary = GameConfig.LEVELS[i]
		var unlocked: Array[String] = GameConfig.plants_for_level(i + 1)
		var plants_ok := not unlocked.is_empty()
		for raw_id in unlocked:
			if not GameConfig.PLANTS.has(raw_id):
				plants_ok = false
		_check("第 %d 关可用植物合法" % (i + 1), plants_ok)
		_check("第 %d 关波次非空" % (i + 1), (level["waves"] as Array).size() > 0)
		_check("第 %d 关初始阳光 > 0" % (i + 1), int(level["start_sun"]) > 0)
		if GameConfig.level_is_night(i):
			night_count += 1
	_check("第 1 关波次引用全局 WAVES",
			(GameConfig.LEVELS[0]["waves"] as Array).size() == GameConfig.WAVES.size())
	_check("夜间关卡共 6 关", night_count == 6)
	_check("第 16 关为夜间场景", GameConfig.level_is_night(15))
	_check("第 30 关为夜间场景", GameConfig.level_is_night(29))
	_check("第 1 关为白天场景", not GameConfig.level_is_night(0))

	var opening: Array[String] = GameConfig.plants_for_level(1)
	_check("第 1 关仅向日葵与豌豆射手",
			opening.size() == 2 and opening.has("sunflower") and opening.has("peashooter"))
	_check("第 7 关解锁双发射手", GameConfig.plants_for_level(7).has("repeater"))
	_check("第 6 关仍未解锁双发射手", not GameConfig.plants_for_level(6).has("repeater"))
	_check("第 11 关解锁寒冰射手", GameConfig.plants_for_level(11).has("snowpea"))
	_check("第 10 关仍未解锁寒冰射手", not GameConfig.plants_for_level(10).has("snowpea"))
	_check("第 30 关解锁全部 11 种植物",
			GameConfig.plants_for_level(30).size() == GameConfig.PLANT_ORDER.size())

	# ---------------- 选卡界面数据 ----------------
	var slot_expect := {1: 2, 3: 3, 7: 6, 11: 7, 17: 9, 25: 10, 30: 10}
	var slots_ok := true
	for level_id in slot_expect.keys():
		if GameConfig.seed_slot_limit(int(level_id)) != int(slot_expect[level_id]):
			slots_ok = false
	_check("槽位上限按关卡推进增长", slots_ok)

	var slots_valid := true
	var last_slot := 0
	for i in GameConfig.LEVELS.size():
		var slot := GameConfig.seed_slot_limit(i + 1)
		if slot < last_slot or slot < 1 or slot > GameConfig.SEED_SLOT_MAX:
			slots_valid = false
		last_slot = slot
	_check("30 关槽位合法且单调不减", slots_valid)

	_check("第 1 关不经选卡", not GameConfig.level_needs_seed_select(0))
	_check("第 6 关不经选卡", not GameConfig.level_needs_seed_select(5))
	_check("第 7 关起经选卡",
			GameConfig.level_needs_seed_select(6) and GameConfig.level_needs_seed_select(29))

	var opening_kinds: Array[String] = GameConfig.zombies_for_level(0)
	_check("第 1 关僵尸种类仅普通僵尸",
			opening_kinds.size() == 1 and opening_kinds[0] == "basic")
	_check("第 3 关僵尸种类含路障僵尸", GameConfig.zombies_for_level(2).has("cone"))
	_check("第 6 关覆盖 5 种非旗帜僵尸", GameConfig.zombies_for_level(5).size() == 5)

	var kinds_valid := true
	for i in GameConfig.LEVELS.size():
		var kinds: Array[String] = GameConfig.zombies_for_level(i)
		if kinds.is_empty():
			kinds_valid = false
		for zombie_id in kinds:
			if zombie_id == "flag" or not GameConfig.ZOMBIES.has(zombie_id):
				kinds_valid = false
	_check("30 关僵尸种类合法且不含旗帜", kinds_valid)
	_check("默认不计入大波追加的旗帜僵尸",
			not GameConfig.zombies_for_level(0).has("flag"))
	_check("include_flag 打开时计入旗帜僵尸",
			GameConfig.zombies_for_level(0, true).has("flag") \
			and GameConfig.zombies_for_level(5, true).size() == 6)

	_check("僵尸中文名表 6 条",
			GameConfig.ZOMBIE_NAMES_CN.size() == GameConfig.ZOMBIES.size())
	var names_ok := true
	for zombie_id in GameConfig.ZOMBIES.keys():
		var name_cn := GameConfig.zombie_name_cn(String(zombie_id))
		if name_cn.is_empty() or name_cn == String(zombie_id):
			names_ok = false
	_check("每个僵尸都有中文名", names_ok)
	_check("未知僵尸名回退不为空",
			not GameConfig.zombie_name_cn("nonexistent").is_empty())


# ---------------- 图鉴 ----------------
func _test_almanac() -> void:
	print("[TEST] --- 植物图鉴 ---")
	var almanac := AlmanacScreen.new()
	add_child(almanac)
	await get_tree().process_frame
	_check("植物卡 11 张", almanac.plant_cards.size() == 11)
	_check("僵尸卡 6 张", almanac.zombie_cards.size() == 6)
	almanac.queue_free()
	await get_tree().process_frame


# ---------------- 设置 ----------------
func _test_settings() -> void:
	print("[TEST] --- 设置 ---")
	var screen := SettingsScreen.new()
	add_child(screen)
	await get_tree().process_frame

	screen.bgm_slider.value = 40.0
	_check("BGM 滑条同步存档", is_equal_approx(SaveManager.bgm_volume, 0.4))
	_check("BGM 滑条同步实际音量", is_equal_approx(SoundManager.bgm_volume, 0.4))

	screen.sfx_slider.value = 70.0
	_check("音效滑条同步存档与音量",
			is_equal_approx(SaveManager.sfx_volume, 0.7) \
			and is_equal_approx(SoundManager.sfx_volume, 0.7))

	screen.mute_check.button_pressed = true
	_check("静音开关同步", SaveManager.muted and SoundManager.is_muted)

	screen.queue_free()
	await get_tree().process_frame


# ---------------- 汇总 ----------------
func _report() -> void:
	print("[TEST] ================= 汇总 =================")
	print("[TEST] 通过 %d 项，失败 %d 项" % [_passed, _failed])
	for label in _failures:
		print("[TEST] 失败项：", label)
	print("[TEST] 已解锁关卡=%d 已通关=%s 最佳击杀=%s" % [
		SaveManager.unlocked_level, str(SaveManager.cleared_levels),
		str(SaveManager.best_kills)])
	get_tree().quit()