class_name CardItem
extends Control
## 单张植物卡：卡片图、阳光消耗、冷却遮罩、选中边框、阳光不足置灰
## 冷却推进由 CardSlot 统一驱动（暂停时冻结）

signal card_pressed(plant_id: String)

const CARD_W := 88.0
const CARD_H := 122.0
const COST_FONT_SIZE := 26
const PAD := 4.0

var plant_id := ""
var cost := 0
var recharge := 0.0

var _cooldown := 0.0
var _cooldown_total := 0.0
var _is_selected := false
var _affordable := true

var _icon: TextureRect = null
var _cost_label: Label = null


func setup(plant_id_value: String) -> void:
	plant_id = plant_id_value
	var data := GameConfig.plant_data(plant_id)
	cost = int(data.get("cost", 0))
	recharge = float(data.get("recharge", 0.0))
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = Vector2(CARD_W, CARD_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "%s  (%d sun)" % [String(data.get("name", plant_id)), cost]
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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			card_pressed.emit(plant_id)
			accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if _cooldown_total > 0.0 and _cooldown > 0.0:
		var ratio := clampf(_cooldown / _cooldown_total, 0.0, 1.0)
		draw_rect(Rect2(0.0, 0.0, size.x, size.y * ratio), Color(0, 0, 0, 0.62))
	if not _affordable:
		draw_rect(rect, Color(0.08, 0.08, 0.12, 0.55))
	draw_rect(rect, Color(1.0, 0.95, 0.4) if _is_selected else Color(0, 0, 0, 0.9),
			false, 4.0 if _is_selected else 3.0)


# ---------------- 状态 ----------------
func tick(delta: float) -> void:
	if _cooldown <= 0.0:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	queue_redraw()


func start_cooldown() -> void:
	_cooldown = recharge
	_cooldown_total = maxf(recharge, 0.001)
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