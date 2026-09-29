class_name GameHud
extends CanvasLayer
## HUD：阳光计数、波次进度、大波横幅、暂停提示、胜负遮罩、快捷键提示
## 文本统一使用英文（Godot 内置字体不含中文字形，避免 Web 导出缺字）

const SUN_BOX_POS := Vector2(24.0, 18.0)
const SUN_BOX_SIZE := Vector2(186.0, 74.0)
const WAVE_PANEL_POS := Vector2(1386.0, 14.0)
const WAVE_PANEL_SIZE := Vector2(398.0, 76.0)
const WAVE_BAR_INSET := Vector2(12.0, 6.0)
const WAVE_LABEL_SIZE := Vector2(374.0, 26.0)
const WAVE_BAR_SIZE := Vector2(374.0, 30.0)
const WAVE_BAR_OFFSET_Y := 36.0
const WAVE_BAR_BG_COLOR := Color(0.07, 0.06, 0.04, 0.92)
const WAVE_BAR_BORDER_COLOR := Color(0.38, 0.3, 0.18)
const WAVE_BAR_FILL_COLOR := Color(0.42, 0.76, 0.3)
const WAVE_BAR_HUGE_FILL_COLOR := Color(0.86, 0.28, 0.22)
const HINT_TEXT := "1-9 select card    P pause    M mute    Esc cancel    Click plant / shovel to dig"

var game: MainGameManager = null
var card_slot: CardSlot = null

var _sun_label: Label = null
var _wave_label: Label = null
var _progress: ProgressBar = null
var _bar_fill_style: StyleBoxFlat = null
var _banner: Label = null
var _pause_label: Label = null
var _overlay: Control = null
var _overlay_title: Label = null
var _overlay_hint: Label = null
var _banner_tween: Tween = null


func setup(game_ref: MainGameManager) -> void:
	game = game_ref


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.name = "HudRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_sun_counter(root)
	_build_card_slot(root)
	_build_wave_panel(root)
	_build_hint(root)
	_build_banner(root)
	_build_pause_label(root)
	_build_overlay(root)

	EventBus.sun_changed.connect(_on_sun_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_over.connect(_on_game_over)
	_on_sun_changed(game.sun if game != null else 0)


func _build_sun_counter(root: Control) -> void:
	var box := ColorRect.new()
	box.color = Color(0.12, 0.1, 0.07, 0.75)
	box.position = SUN_BOX_POS
	box.size = SUN_BOX_SIZE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	var icon := TextureRect.new()
	icon.texture = SpriteLibrary.static_texture("sun")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.position = SUN_BOX_POS + Vector2(8.0, 9.0)
	icon.size = Vector2(56.0, 56.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)

	_sun_label = Label.new()
	_sun_label.position = SUN_BOX_POS + Vector2(70.0, 12.0)
	_sun_label.size = Vector2(108.0, 50.0)
	_sun_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sun_label.add_theme_font_size_override("font_size", 36)
	_sun_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.85))
	_sun_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_sun_label.add_theme_constant_override("outline_size", 6)
	root.add_child(_sun_label)


func _build_card_slot(root: Control) -> void:
	card_slot = CardSlot.new()
	card_slot.setup(game)
	root.add_child(card_slot)
	card_slot.refresh_affordability(game.sun if game != null else 0)


func _build_wave_panel(root: Control) -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.12, 0.1, 0.07, 0.75)
	panel.position = WAVE_PANEL_POS
	panel.size = WAVE_PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	_wave_label = Label.new()
	_wave_label.position = WAVE_PANEL_POS + WAVE_BAR_INSET
	_wave_label.size = WAVE_LABEL_SIZE
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_label.add_theme_font_size_override("font_size", 26)
	_wave_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_wave_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_wave_label.add_theme_constant_override("outline_size", 6)
	_wave_label.text = "Wave 0 / %d" % _total_waves()
	root.add_child(_wave_label)

	# 波数进度条：每波到达推进一步，满格即最后一波；大波时填充色转红
	_progress = ProgressBar.new()
	_progress.position = WAVE_PANEL_POS + Vector2(WAVE_BAR_INSET.x, WAVE_BAR_OFFSET_Y)
	_progress.size = WAVE_BAR_SIZE
	_progress.min_value = 0.0
	_progress.max_value = float(_total_waves())
	_progress.value = 0.0
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.add_theme_stylebox_override("background",
			_make_bar_stylebox(WAVE_BAR_BG_COLOR, WAVE_BAR_BORDER_COLOR, 3, 6))
	_bar_fill_style = _make_bar_stylebox(
			WAVE_BAR_FILL_COLOR, WAVE_BAR_FILL_COLOR, 0, 4)
	_progress.add_theme_stylebox_override("fill", _bar_fill_style)
	root.add_child(_progress)


func _make_bar_stylebox(fill_color: Color, border_color: Color,
		border_width: int, corner_radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill_color
	box.border_color = border_color
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(corner_radius)
	return box


func _build_hint(root: Control) -> void:
	var hint := Label.new()
	hint.text = HINT_TEXT
	hint.position = Vector2(24.0, GameConfig.CANVAS_H - 44.0)
	hint.size = Vector2(1200.0, 32.0)
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9, 0.75))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 5)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)


func _build_banner(root: Control) -> void:
	_banner = Label.new()
	_banner.position = Vector2(0.0, 300.0)
	_banner.size = Vector2(GameConfig.CANVAS_W, 90.0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 58)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner)


func _build_pause_label(root: Control) -> void:
	_pause_label = Label.new()
	_pause_label.position = Vector2(0.0, 460.0)
	_pause_label.size = Vector2(GameConfig.CANVAS_W, 60.0)
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.add_theme_font_size_override("font_size", 46)
	_pause_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_pause_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_pause_label.add_theme_constant_override("outline_size", 8)
	_pause_label.text = "PAUSED"
	_pause_label.visible = false
	_pause_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pause_label)


func _build_overlay(root: Control) -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	root.add_child(_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(shade)

	_overlay_title = Label.new()
	_overlay_title.position = Vector2(0.0, 380.0)
	_overlay_title.size = Vector2(GameConfig.CANVAS_W, 90.0)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_size_override("font_size", 64)
	_overlay_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_overlay_title.add_theme_constant_override("outline_size", 10)
	_overlay.add_child(_overlay_title)

	_overlay_hint = Label.new()
	_overlay_hint.position = Vector2(0.0, 500.0)
	_overlay_hint.size = Vector2(GameConfig.CANVAS_W, 120.0)
	_overlay_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_hint.add_theme_font_size_override("font_size", 32)
	_overlay_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9))
	_overlay_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_overlay_hint.add_theme_constant_override("outline_size", 6)
	_overlay.add_child(_overlay_hint)


# ---------------- 对外 ----------------
## 当前关卡总波数（未接管主控时回退全局配置）
func _total_waves() -> int:
	if game != null:
		return game.total_waves()
	return GameConfig.WAVES.size()


## 全通关模式：隐藏普通胜负标题与提示，把中央区域让给专属结算画面
func set_final_win_mode(enabled: bool) -> void:
	if _overlay_title != null:
		_overlay_title.visible = not enabled
	if _overlay_hint != null:
		_overlay_hint.visible = not enabled


## 普通结算标题/提示是否可见（全通关模式下应为 false）
func is_plain_game_over_visible() -> bool:
	return _overlay_title != null and _overlay_title.visible


func select_card_by_key(keycode: int) -> void:
	if card_slot == null:
		return
	var index := -1
	if keycode >= KEY_1 and keycode <= KEY_9:
		index = keycode - KEY_1
	elif keycode == KEY_0:
		index = 9
	if index >= 0:
		card_slot.select_by_index(index)


func show_banner(text: String) -> void:
	if _banner == null:
		return
	_banner.text = text
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.35)
	_banner_tween.tween_interval(2.0)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


# ---------------- 事件响应 ----------------
func _on_sun_changed(value: int) -> void:
	if _sun_label != null:
		_sun_label.text = str(value)


func _on_wave_started(index: int, total_waves: int, is_huge: bool) -> void:
	if _wave_label != null:
		_wave_label.text = "Wave %d / %d" % [index, total_waves]
	if _progress != null:
		_progress.value = float(index)
	_update_bar_fill_color(is_huge)
	if is_huge:
		show_banner("A HUGE WAVE OF ZOMBIES IS APPROACHING!")
	elif index <= 1:
		show_banner("READY... SET... PLANT!")


## 大波时把进度条填充色切为红色，便于一眼识别
func _update_bar_fill_color(is_huge: bool) -> void:
	if _bar_fill_style == null:
		return
	_bar_fill_style.bg_color = WAVE_BAR_HUGE_FILL_COLOR if is_huge \
			else WAVE_BAR_FILL_COLOR
	if _progress != null:
		_progress.queue_redraw()


func _on_game_paused(is_paused: bool) -> void:
	if _pause_label != null:
		_pause_label.visible = is_paused


func _on_game_over(is_win: bool, killed: int) -> void:
	if _overlay == null:
		return
	_overlay.visible = true
	if _overlay_title != null:
		_overlay_title.text = "LEVEL CLEARED!" if is_win \
				else "THE ZOMBIES ATE YOUR BRAINS!"
		_overlay_title.add_theme_color_override("font_color",
				Color(0.6, 1.0, 0.5) if is_win else Color(1.0, 0.4, 0.35))
	if _overlay_hint != null:
		_overlay_hint.text = "Zombies defeated: %d\n\nPress R to restart" % killed
	if _pause_label != null:
		_pause_label.visible = false