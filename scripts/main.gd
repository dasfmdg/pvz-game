class_name MainRouter
extends Node2D
## 启动入口：界面路由（主菜单 → 关卡选择 / 图鉴 / 设置 → 关卡游戏）
## 只有进入游戏态才实例化 MainGameManager；离开游戏态时释放主控

enum E_State { MENU, LEVEL_SELECT, ALMANAC, SETTINGS, GAME }

const GAME_OVER_LAYER := 20

var state := E_State.MENU
var game: MainGameManager = null
var current_screen: Control = null
var current_level := 0

var _ui_root: Control = null
var _overlay_layer: CanvasLayer = null
var _overlay_panel: Control = null


func _ready() -> void:
	_ui_root = Control.new()
	_ui_root.name = "UiRoot"
	_ui_root.size = Vector2(GameConfig.CANVAS_W, GameConfig.CANVAS_H)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)
	_build_game_over_overlay()
	EventBus.game_over.connect(_on_game_over)
	show_menu()


# ---------------- 界面切换 ----------------
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
	screen.level_chosen.connect(start_level)
	screen.back_pressed.connect(show_menu)
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
func start_level(index: int) -> void:
	state = E_State.GAME
	current_level = index
	_set_screen(null)
	_hide_game_over()
	_clear_game()
	var manager := MainGameManager.new()
	manager.setup_level(index)
	manager.restart_requested.connect(_on_restart)
	add_child(manager)
	game = manager


## 离开游戏态，回到关卡选择
func return_to_level_select() -> void:
	show_level_select()


func is_game_over_visible() -> bool:
	return _overlay_panel != null and _overlay_panel.visible


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


func _show_game_over() -> void:
	if _overlay_panel != null:
		_overlay_panel.visible = true


func _hide_game_over() -> void:
	if _overlay_panel != null:
		_overlay_panel.visible = false


func _on_game_over(is_win: bool, killed: int) -> void:
	if is_win:
		SaveManager.mark_cleared(current_level, killed)
	_show_game_over()


func _on_restart() -> void:
	start_level(current_level)


func _on_quit() -> void:
	get_tree().quit()