class_name SeedCard
extends Control
## 选卡界面的可选植物卡：卡片图 + 阳光数字 + 已选黄框与顺序角标 + 槽位已满置灰
## 与战场卡槽 CardItem（88×122，状态是冷却 / 阳光不足）不同，这里的状态是已选顺序 / 槽位已满

signal card_pressed(plant_id: String)

const CARD_W := 132.0
const CARD_H := 182.0
const COST_FONT_SIZE := 32
const BADGE_FONT_SIZE := 26
const BADGE_SIZE := 40.0
const PAD := 6.0

var plant_id := ""
var cost := 0

var _picked := false
var _order := 0
var _dimmed := false

var _badge_back: ColorRect = null
var _badge: Label = null


func setup(plant_id_value: String) -> void:
	plant_id = plant_id_value
	var data := GameConfig.plant_data(plant_id)
	cost = int(data.get("cost", 0))
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = Vector2(CARD_W, CARD_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.16, 0.13, 0.09, 0.94)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# 贴图缺失时只留深色底板 + 阳光数字，不留空白
	var icon := TextureRect.new()
	icon.texture = SpriteLibrary.card_texture(plant_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = PAD
	icon.offset_top = PAD
	icon.offset_right = -PAD
	icon.offset_bottom = -PAD
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

	var cost_label := UiKit.make_label(str(cost), COST_FONT_SIZE, Color(1.0, 0.98, 0.85))
	cost_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cost_label.offset_top = -42.0
	cost_label.offset_bottom = -6.0
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(cost_label)

	_badge_back = ColorRect.new()
	_badge_back.color = Color(1.0, 0.85, 0.2, 0.92)
	_badge_back.position = Vector2(CARD_W - BADGE_SIZE, 0.0)
	_badge_back.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	_badge_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_back.visible = false
	add_child(_badge_back)

	_badge = UiKit.make_label("", BADGE_FONT_SIZE, Color(0.18, 0.12, 0.0))
	_badge.position = Vector2(CARD_W - BADGE_SIZE, 0.0)
	_badge.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_constant_override("outline_size", 0)
	_badge.visible = false
	add_child(_badge)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			card_pressed.emit(plant_id)
			accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if _dimmed:
		draw_rect(rect, Color(0.08, 0.08, 0.12, 0.55))
	draw_rect(rect, Color(1.0, 0.95, 0.4) if _picked else Color(0, 0, 0, 0.9),
			false, 4.0 if _picked else 3.0)


# ---------------- 状态 ----------------
## 已选状态与顺序角标（order 为 1 基序号，取消时传 0）
func set_picked(value: bool, order: int) -> void:
	_picked = value
	_order = order if value else 0
	if _badge != null:
		_badge.text = str(_order)
		_badge.visible = value
	if _badge_back != null:
		_badge_back.visible = value
	queue_redraw()


## 槽位已满且本卡未选时的置灰
func set_dimmed(value: bool) -> void:
	if _dimmed == value:
		return
	_dimmed = value
	queue_redraw()