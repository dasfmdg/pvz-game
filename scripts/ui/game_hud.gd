class_name GameHud
extends CanvasLayer
## HUD：阳光计数、波次进度、大波横幅、暂停提示、胜负遮罩、快捷键提示
## 文本统一使用英文（Godot 内置字体不含中文字形，避免 Web 导出缺字）

const SUN_BOX_POS := Vector2(24.0, 18.0)
const SUN_BOX_SIZE := Vector2(186.0, 74.0)
## 计数框内阳光图标的相对偏移与尺寸（阳光飞行动画终点由此推导）
const SUN_ICON_INSET := Vector2(8.0, 9.0)
const SUN_ICON_SIZE := Vector2(56.0, 56.0)
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
## 进度条追赶速度（波/秒）：波次到达时平滑推进而非瞬跳
const WAVE_BAR_CHASE_SPEED := 4.0
## 大波旗帜刻度：旗杆宽度、旗帜尺寸与「未升起 / 已升起」两套配色
const WAVE_TICK_WIDTH := 2.0
const WAVE_FLAG_SIZE := Vector2(12.0, 9.0)
const WAVE_TICK_COLOR_PENDING := Color(0.42, 0.34, 0.18, 0.9)
const WAVE_TICK_COLOR_RAISED := Color(1.0, 0.85, 0.32)
const WAVE_FLAG_COLOR_PENDING := Color(0.4, 0.32, 0.16, 0.85)
const WAVE_FLAG_COLOR_RAISED := Color(0.96, 0.74, 0.2)
## 迷你僵尸标记：随进度沿条身从左向右推进，复用行走精灵表首帧（零新素材）
const WAVE_MARKER_SIZE := Vector2(30.0, 26.0)
const HINT_TEXT := "1-9 select card    P pause    M mute    Esc cancel    Click plant / shovel to dig"

## 暂停面板：半透明底 + 标题 + 存/读档按钮 + 状态行（HUD 文案统一英文）
const PAUSE_PANEL_SIZE := Vector2(900.0, 470.0)
const PAUSE_PANEL_BG := Color(0.06, 0.05, 0.04, 0.82)
const PAUSE_TITLE_TOP := 18.0
const PAUSE_HINT_TOP := 92.0
const PAUSE_SAVE_ROW_TOP := 170.0
const PAUSE_LOAD_ROW_TOP := 262.0
const PAUSE_STATUS_TOP := 366.0
const PAUSE_BUTTON_W := 180.0
const PAUSE_BUTTON_H := 64.0
const PAUSE_BUTTON_GAP := 24.0

var game: MainGameManager = null
var card_slot: CardSlot = null

var _sun_label: Label = null
var _wave_label: Label = null
var _progress: ProgressBar = null
var _bar_fill_style: StyleBoxFlat = null
## 进度条显示值与目标值（波数）：显示值逐帧追赶目标值，实现平滑推进
var _wave_bar_display := 0.0
var _wave_bar_target := 0.0
## 当前关卡大波的 1 基序号，以及对应的旗杆刻度与旗帜节点
var _huge_waves: Array[int] = []
var _tick_marks: Array[ColorRect] = []
var _tick_flags: Array[Polygon2D] = []
## 迷你僵尸标记：随进度推进；精灵表缺失时为 null
var _wave_marker: TextureRect = null
var _banner: Label = null
var _pause_panel: Control = null
var _pause_status: Label = null
var _save_buttons: Array[Button] = []
var _load_buttons: Array[Button] = []
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
	_build_pause_panel(root)
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
	icon.position = SUN_BOX_POS + SUN_ICON_INSET
	icon.size = SUN_ICON_SIZE
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

	# 波数进度条：逐帧追赶目标波数实现平滑推进；大波位置预置旗帜刻度，到达后升起
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
	_build_wave_ticks(root)
	_build_wave_marker(root)


## 大波旗帜刻度：按大波在总波数中的位置，在进度条上放置旗杆与旗帜
## 未到达为暗色，到达后升起为亮金色；节点名形如 WaveTick3 / WaveFlag3（波次为 1 基）
func _build_wave_ticks(root: Control) -> void:
	_huge_waves = _huge_wave_indices()
	if _huge_waves.is_empty():
		return
	var total := float(maxi(_total_waves(), 1))
	var bar_pos := WAVE_PANEL_POS + Vector2(WAVE_BAR_INSET.x, WAVE_BAR_OFFSET_Y)
	for wave_num in _huge_waves:
		var center_x := bar_pos.x + WAVE_BAR_SIZE.x * (float(wave_num) / total)

		var mark := ColorRect.new()
		mark.name = "WaveTick%d" % wave_num
		mark.color = WAVE_TICK_COLOR_PENDING
		mark.position = Vector2(center_x - WAVE_TICK_WIDTH * 0.5, bar_pos.y)
		mark.size = Vector2(WAVE_TICK_WIDTH, WAVE_BAR_SIZE.y)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(mark)
		_tick_marks.append(mark)

		# 旗杆顶部向右飘出的三角旗，整块保持在进度条高度内，不挤压上方波次文字
		var flag := Polygon2D.new()
		flag.name = "WaveFlag%d" % wave_num
		flag.color = WAVE_FLAG_COLOR_PENDING
		flag.polygon = PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(WAVE_FLAG_SIZE.x, WAVE_FLAG_SIZE.y * 0.5),
			Vector2(0.0, WAVE_FLAG_SIZE.y),
		])
		flag.position = Vector2(center_x - WAVE_TICK_WIDTH * 0.5, bar_pos.y + 4.0)
		root.add_child(flag)
		_tick_flags.append(flag)


## 当前关卡大波的 1 基序号；未接管主控时回退全局配置
func _huge_wave_indices() -> Array[int]:
	var waves: Array = game.level_waves if game != null else GameConfig.WAVES
	var out: Array[int] = []
	for i in waves.size():
		if bool((waves[i] as Dictionary).get("huge", false)):
			out.append(i + 1)
	return out


## 迷你僵尸标记：复用行走精灵表首帧，沿进度条从左向右推进（零新素材）
## 精灵表缺失时不创建，不阻断 HUD
func _build_wave_marker(root: Control) -> void:
	var head := UiKit.sheet_first_frame("z_basic_walk")
	if head == null:
		return
	_wave_marker = TextureRect.new()
	_wave_marker.name = "WaveMarker"
	_wave_marker.texture = head
	_wave_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wave_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wave_marker.size = WAVE_MARKER_SIZE
	_wave_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_wave_marker)
	_place_wave_marker()


## 按当前进度把迷你僵尸摆到条身对应位置（首尾均保持在条内）
func _place_wave_marker() -> void:
	if _wave_marker == null:
		return
	var total := float(maxi(_total_waves(), 1))
	var bar_pos := WAVE_PANEL_POS + Vector2(WAVE_BAR_INSET.x, WAVE_BAR_OFFSET_Y)
	var travel := maxf(WAVE_BAR_SIZE.x - WAVE_MARKER_SIZE.x, 0.0)
	var ratio := clampf(_wave_bar_display / total, 0.0, 1.0)
	_wave_marker.position = Vector2(
			bar_pos.x + travel * ratio,
			bar_pos.y + (WAVE_BAR_SIZE.y - WAVE_MARKER_SIZE.y) * 0.5)


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


func _build_pause_panel(root: Control) -> void:
	_pause_panel = Control.new()
	_pause_panel.size = PAUSE_PANEL_SIZE
	_pause_panel.position = Vector2(
			(GameConfig.CANVAS_W - PAUSE_PANEL_SIZE.x) * 0.5,
			(GameConfig.CANVAS_H - PAUSE_PANEL_SIZE.y) * 0.5)
	# STOP：面板打开时吞掉点击，避免误触到草坪上的种植 / 收阳光
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_panel.visible = false
	root.add_child(_pause_panel)

	var shade := ColorRect.new()
	shade.color = PAUSE_PANEL_BG
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_panel.add_child(shade)

	var title := Label.new()
	title.text = "PAUSED"
	title.position = Vector2(0.0, PAUSE_TITLE_TOP)
	title.size = Vector2(PAUSE_PANEL_SIZE.x, 64.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_panel.add_child(title)

	var hint := Label.new()
	hint.text = "P resume    M mute    Esc cancel"
	hint.position = Vector2(0.0, PAUSE_HINT_TOP)
	hint.size = Vector2(PAUSE_PANEL_SIZE.x, 32.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9, 0.8))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 5)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_panel.add_child(hint)

	_save_buttons = _build_slot_row(PAUSE_SAVE_ROW_TOP, "Save", _on_save_pressed)
	_load_buttons = _build_slot_row(PAUSE_LOAD_ROW_TOP, "Load", _on_load_pressed)

	_pause_status = Label.new()
	_pause_status.position = Vector2(0.0, PAUSE_STATUS_TOP)
	_pause_status.size = Vector2(PAUSE_PANEL_SIZE.x, 36.0)
	_pause_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_status.add_theme_font_size_override("font_size", 26)
	_pause_status.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	_pause_status.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_pause_status.add_theme_constant_override("outline_size", 5)
	_pause_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_panel.add_child(_pause_status)

	_refresh_slot_buttons()


## 一排槽位按钮（verb = Save / Load）
func _build_slot_row(top: float, verb: String, on_pressed: Callable) -> Array[Button]:
	var buttons: Array[Button] = []
	var count := SaveManager.RUN_SLOT_MAX
	var total := float(count) * PAUSE_BUTTON_W + float(count - 1) * PAUSE_BUTTON_GAP
	var start_x := (PAUSE_PANEL_SIZE.x - total) * 0.5
	for i in count:
		var slot := i + 1
		var button := UiKit.make_button("%s %d" % [verb, slot], 32)
		button.custom_minimum_size = Vector2(PAUSE_BUTTON_W, PAUSE_BUTTON_H)
		button.size = Vector2(PAUSE_BUTTON_W, PAUSE_BUTTON_H)
		button.position = Vector2(start_x + float(i) * (PAUSE_BUTTON_W + PAUSE_BUTTON_GAP), top)
		button.pressed.connect(on_pressed.bind(slot))
		_pause_panel.add_child(button)
		buttons.append(button)
	return buttons


## 无档槽位的读档按钮置灰
func _refresh_slot_buttons() -> void:
	for i in _load_buttons.size():
		_load_buttons[i].disabled = not SaveManager.has_run(i + 1)


func _set_pause_status(text: String) -> void:
	if _pause_status != null:
		_pause_status.text = text


## 存档：抓取当前局快照写入槽位，并给出状态反馈
func _on_save_pressed(slot: int) -> void:
	if game == null:
		return
	var ok := SaveManager.save_run(slot, game.capture_snapshot())
	_set_pause_status("Saved to slot %d" % slot if ok else "Save failed (slot %d)" % slot)
	_refresh_slot_buttons()


## 读档：交由主控信号 → 路由重建关卡；无档时只给状态反馈
func _on_load_pressed(slot: int) -> void:
	if not SaveManager.has_run(slot):
		_set_pause_status("No save in slot %d" % slot)
		return
	if game == null:
		return
	_set_pause_status("Loading slot %d..." % slot)
	game.request_load(slot)


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
## 阳光计数框图标的中心点（画布坐标）：阳光收集飞行动画的终点
func sun_box_center() -> Vector2:
	return SUN_BOX_POS + SUN_ICON_INSET + SUN_ICON_SIZE * 0.5


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
	# 只设目标值，由 _process 逐帧追赶，避免进度条瞬跳
	_wave_bar_target = float(index)
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


func _process(delta: float) -> void:
	_update_wave_bar(delta)


## 进度条显示值逐帧追赶目标波数：追赶而非瞬跳，让每波推进有可见动画
func _update_wave_bar(delta: float) -> void:
	if _progress == null:
		return
	if is_equal_approx(_wave_bar_display, _wave_bar_target):
		_wave_bar_display = _wave_bar_target
	else:
		_wave_bar_display = move_toward(_wave_bar_display, _wave_bar_target,
				WAVE_BAR_CHASE_SPEED * delta)
	_progress.value = _wave_bar_display
	_refresh_tick_states()
	_place_wave_marker()


## 已到达的大波刻度与旗帜换成升起的亮金色，未到达保持暗色
## 换色前先比较，避免每帧重复赋值触发无谓重绘
func _refresh_tick_states() -> void:
	for i in _huge_waves.size():
		var raised := _wave_bar_display >= float(_huge_waves[i]) - 0.001
		var tick_color := WAVE_TICK_COLOR_RAISED if raised else WAVE_TICK_COLOR_PENDING
		var flag_color := WAVE_FLAG_COLOR_RAISED if raised else WAVE_FLAG_COLOR_PENDING
		if i < _tick_marks.size() and _tick_marks[i].color != tick_color:
			_tick_marks[i].color = tick_color
		if i < _tick_flags.size() and _tick_flags[i].color != flag_color:
			_tick_flags[i].color = flag_color


func _on_game_paused(is_paused: bool) -> void:
	if _pause_panel == null:
		return
	if is_paused:
		_refresh_slot_buttons()
		_set_pause_status("")
	_pause_panel.visible = is_paused


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
	if _pause_panel != null:
		_pause_panel.visible = false