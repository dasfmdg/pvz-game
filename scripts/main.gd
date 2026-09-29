class_name MainRouter
extends Node2D
## 启动入口：界面路由（启动加载页 → 主菜单 → 关卡选择 / 图鉴 / 设置 → 选卡 → 关卡游戏）
## 只有进入游戏态才实例化 MainGameManager；离开游戏态时释放主控

enum E_State { SPLASH, MENU, LEVEL_SELECT, SEED_SELECT, ALMANAC, SETTINGS, GAME }

const GAME_OVER_LAYER := 20

## 全通关（最后一关胜利）专属结算画面：英文原图 + 中文译句 + 标题 + 统计
const FINAL_WIN_IMAGE_PATH := "res://assets/ui/final_win.png"
const FINAL_WIN_IMAGE_HEIGHT := 400.0
const FINAL_WIN_IMAGE_TOP := 80.0
const FINAL_WIN_CAPTION_TOP := 498.0
const FINAL_WIN_TITLE_TOP := 552.0
const FINAL_WIN_STATS_TOP := 644.0
const FINAL_WIN_TITLE_COLOR := Color(1.0, 0.9, 0.45)
## 原图英文文案 "Congratulations! You Ate Zombie Brains!" 的中文译句
const FINAL_WIN_CAPTION_TEXT := "恭喜！你吃掉了僵尸的脑子！"

var state := E_State.MENU
var game: MainGameManager = null
var current_screen: Control = null
var current_level := 0
## 上次选卡结果（仅路由内存，供重试沿用，不落存档）
var current_seed_selection: Array[String] = []

var _seed_selection_level := -1

var _ui_root: Control = null
var _overlay_layer: CanvasLayer = null
var _overlay_panel: Control = null
var _final_win_image: TextureRect = null
var _final_win_caption: Label = null
var _final_win_title: Label = null
var _final_win_stats: Label = null


func _ready() -> void:
	_ui_root = Control.new()
	_ui_root.name = "UiRoot"
	_ui_root.size = Vector2(GameConfig.CANVAS_W, GameConfig.CANVAS_H)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)
	_build_game_over_overlay()
	EventBus.game_over.connect(_on_game_over)
	show_splash()


# ---------------- 界面切换 ----------------
## 启动加载页：封面图先显示出来，点击或按键后进主菜单
func show_splash() -> void:
	state = E_State.SPLASH
	_clear_game()
	_hide_game_over()
	var screen := SplashScreen.new()
	screen.dismissed.connect(show_menu)
	_set_screen(screen)


func show_menu() -> void:
	state = E_State.MENU
	_clear_game()
	_hide_game_over()
	var screen := MenuScreen.new()
	screen.start_pressed.connect(show_level_select)
	screen.almanac_pressed.connect(show_almanac)
	screen.settings_pressed.connect(show_settings)
	screen.quit_pressed.connect(_on_quit)
	_set_screen(screen)


func show_level_select() -> void:
	state = E_State.LEVEL_SELECT
	_clear_game()
	_hide_game_over()
	var screen := LevelSelectScreen.new()
	screen.level_chosen.connect(_on_level_chosen)
	screen.back_pressed.connect(show_menu)
	_set_screen(screen)


## 关卡选择回调：第 7 关起先经选卡界面，其余直接进关
func _on_level_chosen(index: int) -> void:
	if GameConfig.level_needs_seed_select(index):
		show_seed_select(index)
		return
	start_level(index)


## 选卡界面：预选上次同关的选卡结果
func show_seed_select(index: int) -> void:
	state = E_State.SEED_SELECT
	current_level = clampi(index, 0, GameConfig.LEVELS.size() - 1)
	_clear_game()
	_hide_game_over()
	var screen := SeedSelectScreen.new()
	screen.setup(current_level, _selection_for(current_level))
	screen.start_pressed.connect(_on_seed_confirmed)
	screen.back_pressed.connect(show_level_select)
	_set_screen(screen)


func show_almanac() -> void:
	state = E_State.ALMANAC
	_clear_game()
	_hide_game_over()
	var screen := AlmanacScreen.new()
	screen.back_pressed.connect(show_menu)
	_set_screen(screen)


func show_settings() -> void:
	state = E_State.SETTINGS
	_clear_game()
	_hide_game_over()
	var screen := SettingsScreen.new()
	screen.back_pressed.connect(show_menu)
	_set_screen(screen)


## 进入关卡：实例化主控并安装关卡数据（加入场景树前完成）
## selected_plants 为空表示按解锁表全量携带（第 1~6 关与回归工具走此路径）
func start_level(index: int, selected_plants: Array = []) -> void:
	state = E_State.GAME
	current_level = index
	_set_screen(null)
	_hide_game_over()
	_clear_game()
	var manager := MainGameManager.new()
	manager.setup_level(index, selected_plants)
	manager.restart_requested.connect(_on_restart)
	add_child(manager)
	game = manager


## 选卡确认：记录本关选卡结果并进关（重试沿用，不落存档）
func _on_seed_confirmed(plants: Array) -> void:
	current_seed_selection = []
	for raw_id in plants:
		current_seed_selection.append(String(raw_id))
	_seed_selection_level = current_level
	start_level(current_level, current_seed_selection)


## 上次同关的选卡结果（不同关卡返回空，避免把旧关卡选择带进重试）
func _selection_for(index: int) -> Array:
	if _seed_selection_level == index:
		return current_seed_selection
	return []


## 离开游戏态，回到关卡选择
func return_to_level_select() -> void:
	show_level_select()


func is_game_over_visible() -> bool:
	return _overlay_panel != null and _overlay_panel.visible


## 全通关结算画面是否可见（图片 / 译句 / 标题 / 统计必须同步显示）
func is_final_win_visible() -> bool:
	return _final_win_image != null and _final_win_image.visible \
		and _final_win_caption != null and _final_win_caption.visible \
		and _final_win_title != null and _final_win_title.visible \
		and _final_win_stats != null and _final_win_stats.visible


# ---------------- 内部 ----------------
func _set_screen(screen: Control) -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = screen
	if screen != null:
		_ui_root.add_child(screen)


func _clear_game() -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
	game = null


func _build_game_over_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = GAME_OVER_LAYER
	_overlay_layer.name = "GameOverLayer"
	add_child(_overlay_layer)

	_overlay_panel = Control.new()
	_overlay_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_panel.visible = false
	_overlay_layer.add_child(_overlay_panel)

	var retry := UiKit.make_button("重试", 38)
	retry.custom_minimum_size = Vector2(360.0, 96.0)
	retry.position = Vector2(GameConfig.CANVAS_W * 0.5 - 190.0, 780.0)
	retry.pressed.connect(_on_restart)
	_overlay_panel.add_child(retry)

	var back := UiKit.make_button("返回关卡选择", 38)
	back.custom_minimum_size = Vector2(360.0, 96.0)
	back.position = Vector2(GameConfig.CANVAS_W * 0.5 - 190.0, 900.0)
	back.pressed.connect(return_to_level_select)
	_overlay_panel.add_child(back)

	_build_final_win_banner()


## 全通关专属结算：英文原图 + 中文译句 + 中文标题 + 累计击杀统计（默认隐藏）
func _build_final_win_banner() -> void:
	_final_win_image = UiKit.make_texture(FINAL_WIN_IMAGE_PATH)
	# make_texture 默认铺满父容器，这里改回左上锚点后按等比尺寸居中摆放
	_final_win_image.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_final_win_image.size = Vector2(
			FINAL_WIN_IMAGE_HEIGHT * _image_ratio(FINAL_WIN_IMAGE_PATH), FINAL_WIN_IMAGE_HEIGHT)
	_final_win_image.position = Vector2(
			GameConfig.CANVAS_W * 0.5 - _final_win_image.size.x * 0.5, FINAL_WIN_IMAGE_TOP)
	_final_win_image.visible = false
	_overlay_panel.add_child(_final_win_image)

	_final_win_caption = UiKit.make_label(FINAL_WIN_CAPTION_TEXT, 30, Color(0.95, 1.0, 0.9))
	_final_win_caption.size = Vector2(GameConfig.CANVAS_W, 40.0)
	_final_win_caption.position = Vector2(0.0, FINAL_WIN_CAPTION_TOP)
	_final_win_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_final_win_caption.visible = false
	_overlay_panel.add_child(_final_win_caption)

	_final_win_title = UiKit.make_label("全部关卡通关！", 64, FINAL_WIN_TITLE_COLOR)
	_final_win_title.size = Vector2(GameConfig.CANVAS_W, 80.0)
	_final_win_title.position = Vector2(0.0, FINAL_WIN_TITLE_TOP)
	_final_win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_final_win_title.visible = false
	_overlay_panel.add_child(_final_win_title)

	_final_win_stats = UiKit.make_label("", 32, Color(1.0, 1.0, 0.9))
	_final_win_stats.size = Vector2(GameConfig.CANVAS_W, 44.0)
	_final_win_stats.position = Vector2(0.0, FINAL_WIN_STATS_TOP)
	_final_win_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_final_win_stats.visible = false
	_overlay_panel.add_child(_final_win_stats)


## final_win.png 是 757×870 透明底绿字图，等比缩放避免文字变形
func _image_ratio(path: String) -> float:
	var tex := UiKit.load_texture(path)
	if tex != null:
		var size := tex.get_size()
		if size.y > 0.0:
			return size.x / size.y
	return 1.0


func _show_game_over() -> void:
	if _overlay_panel != null:
		_overlay_panel.visible = true


func _hide_game_over() -> void:
	if _overlay_panel != null:
		_overlay_panel.visible = false
	_set_final_win_visible(false)


func _on_game_over(is_win: bool, killed: int) -> void:
	if is_win:
		SaveManager.mark_cleared(current_level, killed)
	_set_final_win_visible(is_win and is_final_level())
	_show_game_over()


## 是否处于最后一关
func is_final_level() -> bool:
	return current_level >= GameConfig.LEVELS.size() - 1


## 全通关结算：显示专属贴图/译句/标题/统计，并让 HUD 让出中央区域
## （HUD 每个关卡重新构建，隐藏无需回滚）
func _set_final_win_visible(show_flag: bool) -> void:
	if _final_win_image != null:
		_final_win_image.visible = show_flag
	if _final_win_caption != null:
		_final_win_caption.visible = show_flag
	if _final_win_title != null:
		_final_win_title.visible = show_flag
	if _final_win_stats != null:
		_final_win_stats.visible = show_flag
	if not show_flag:
		return
	if _final_win_stats != null:
		_final_win_stats.text = "累计最佳击杀：%d" % SaveManager.total_best_kills()
	if game != null and game.hud != null:
		game.hud.set_final_win_mode(true)


func _on_restart() -> void:
	start_level(current_level, _selection_for(current_level))


func _on_quit() -> void:
	get_tree().quit()