class_name CardItem
extends Control
## 单张植物卡：卡片图、阳光消耗、冷却遮罩、冷却倒计时、冷却完毕闪烁、选中边框、阳光不足置灰
## 冷却推进由 CardSlot 统一驱动（暂停时冻结）
## 表现对齐参考实现 js/ui.js：冷却遮罩按剩余比例自上而下覆盖；只有「冷却已结束且阳光不足」才整体置灰

signal card_pressed(plant_id: String)

const CARD_W := 88.0
const CARD_H := 122.0
const COST_FONT_SIZE := 26
const TIMER_FONT_SIZE := 40
const PAD := 4.0

## 冷却遮罩 / 置灰 / 选中与冷却完毕闪烁
const SHADE_COLOR := Color(0, 0, 0, 0.62)
const DIM_COLOR := Color(0.08, 0.08, 0.12, 0.55)
const SELECTED_COLOR := Color(1.0, 0.95, 0.4)
const READY_FLASH_COLOR := Color(1.0, 0.95, 0.4)
const READY_FLASH_TIME := 0.6

var plant_id := ""
var cost := 0
var recharge := 0.0

var _cooldown := 0.0
var _cooldown_total := 0.0
var _ready_flash := 0.0
var _shown_seconds := -1
var _is_selected := false
var _affordable := true

var _icon: TextureRect = null
var _cost_label: Label = null
var _timer_label: Label = null


func setup(plant_id_value: String) -> void:
	plant_id = plant_id_value
	var data := GameConfig.plant_data(plant_id)
	cost = int(data.get("cost", 0))
	recharge = float(data.get("recharge", 0.0))
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = Vector2(CARD_W, CARD_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "%s  (%d sun)\nCooldown: %.1fs" % [
			String(data.get("name", plant_id)), cost, recharge]
	_build()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.16, 0.13, 0.09, 0.94)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_icon = TextureRect.new()
	_icon.texture = SpriteLibrary.card_texture(plant_id)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = PAD
	_icon.offset_top = PAD
	_icon.offset_right = -PAD
	_icon.offset_bottom = -PAD
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_cost_label = Label.new()
	_cost_label.text = str(cost)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_cost_label.offset_top = -32.0
	_cost_label.offset_bottom = -2.0
	_cost_label.add_theme_font_size_override("font_size", COST_FONT_SIZE)
	_cost_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.85))
	_cost_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_cost_label.add_theme_constant_override("outline_size", 6)
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cost_label)

	# 冷却剩余秒数：居中大字，只在冷却中显示
	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_timer_label.add_theme_font_size_override("font_size", TIMER_FONT_SIZE)
	_timer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_timer_label.add_theme_constant_override("outline_size", 8)
	_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_label.visible = false
	add_child(_timer_label)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			card_pressed.emit(plant_id)
			accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if _cooldown_total > 0.0 and recharge_left() > 0.0:
		var ratio := clampf(recharge_left() / _cooldown_total, 0.0, 1.0)
		draw_rect(Rect2(0.0, 0.0, size.x, size.y * ratio), SHADE_COLOR)
	if shows_unaffordable():
		draw_rect(rect, DIM_COLOR)
	if is_flashing():
		var alpha := (_ready_flash / READY_FLASH_TIME) * 0.45
		draw_rect(rect, Color(READY_FLASH_COLOR.r, READY_FLASH_COLOR.g,
				READY_FLASH_COLOR.b, alpha))
	draw_rect(rect, SELECTED_COLOR if _is_selected else Color(0, 0, 0, 0.9),
			false, 4.0 if _is_selected else 3.0)


# ---------------- 状态 ----------------
func tick(delta: float) -> void:
	if is_flashing():
		_ready_flash = maxf(0.0, _ready_flash - delta)
		queue_redraw()
	if _cooldown <= 0.0:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown <= 0.0:
		_ready_flash = READY_FLASH_TIME   # 冷却完毕瞬间闪一次
	_sync_timer_label()
	queue_redraw()


func start_cooldown() -> void:
	_cooldown = maxf(recharge, 0.0)
	_cooldown_total = maxf(recharge, 0.001)
	_ready_flash = 0.0
	_sync_timer_label()
	queue_redraw()


func set_selected(value: bool) -> void:
	if _is_selected == value:
		return
	_is_selected = value
	queue_redraw()


func set_affordable(value: bool) -> void:
	if _affordable == value:
		return
	_affordable = value
	queue_redraw()


func is_ready() -> bool:
	return _cooldown <= 0.0


func can_use() -> bool:
	return _cooldown <= 0.0 and _affordable


## 置灰条件对齐参考实现：冷却中不置灰，冷却结束且阳光不足才置灰
func shows_unaffordable() -> bool:
	return (not _affordable) and is_ready()


## 剩余冷却秒数（0 表示已就绪）
func recharge_left() -> float:
	return _cooldown


## 冷却完毕闪烁是否仍在播放
func is_flashing() -> bool:
	return _ready_flash > 0.0


## 冷却倒计时标签是否可见
func is_timer_visible() -> bool:
	return _timer_label != null and _timer_label.visible


## 倒计时文案只按整秒刷新，避免每帧改文本
func _sync_timer_label() -> void:
	if _timer_label == null:
		return
	var running := _cooldown > 0.0
	_timer_label.visible = running
	if not running:
		_shown_seconds = -1
		return
	var seconds := int(ceilf(_cooldown))
	if seconds != _shown_seconds:
		_shown_seconds = seconds
		_timer_label.text = str(seconds)