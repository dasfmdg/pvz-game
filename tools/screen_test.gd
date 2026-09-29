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

	_check("初始进入主菜单",
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
	_check("关卡选择含 5 个按钮", select != null and select.level_buttons.size() == 5)
	var lock_consistent := true
	if select != null:
		for index in select.level_buttons.size():
			if select.level_buttons[index].disabled == SaveManager.is_unlocked(index):
				lock_consistent = false
	_check("锁定态与存档一致", lock_consistent)

	router.start_level(0)
	await get_tree().process_frame
	_check("进入关卡后主控存在",
			router.game != null and router.game is MainGameManager)
	_check("主控已挂载到路由", router.game != null and router.game.get_parent() == router)
	_check("主控关卡数据为第 0 关", router.game != null and router.game.level_index == 0)

	var game_ref: MainGameManager = router.game
	game_ref.end_game(true)
	await get_tree().process_frame
	_check("胜利后写入存档", SaveManager.best_kills.has(0))
	_check("结算遮罩出现", router.is_game_over_visible())

	router.return_to_level_select()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("返回关卡选择",
			router.state == MainRouter.E_State.LEVEL_SELECT \
			and router.current_screen is LevelSelectScreen)
	_check("离开游戏态后主控被释放",
			router.game == null and not is_instance_valid(game_ref))

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


# ---------------- 关卡数据 ----------------
func _test_levels() -> void:
	print("[TEST] --- 关卡数据 ---")
	_check("关卡数量为 5", GameConfig.LEVELS.size() == 5)
	for i in GameConfig.LEVELS.size():
		var level: Dictionary = GameConfig.LEVELS[i]
		var plants_ok := true
		for raw_id in (level["plants"] as Array):
			if not GameConfig.PLANTS.has(String(raw_id)):
				plants_ok = false
		_check("第 %d 关植物 id 合法" % (i + 1), plants_ok)
		_check("第 %d 关波次非空" % (i + 1), (level["waves"] as Array).size() > 0)
		_check("第 %d 关初始阳光 > 0" % (i + 1), int(level["start_sun"]) > 0)
	_check("第 1 关波次引用全局 WAVES",
			(GameConfig.LEVELS[0]["waves"] as Array).size() == GameConfig.WAVES.size())


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