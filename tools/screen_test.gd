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

	router.queue_free()
	await get_tree().process_frame


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