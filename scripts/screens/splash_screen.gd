class_name SplashScreen
extends Control
## 启动加载页：PvZ 经典封面居中展示，点击或按键后进入主菜单
## 原图 512×384（4:3）与画布 1920×1080（16:9）比例不同，因此居中放大 2 倍 + 深色底，
## 不做拉伸铺满，避免画面变形；贴图缺失时只显示深色底与提示，不阻断进入主菜单

signal dismissed()

const IMAGE_PATH := "res://assets/ui/splash.jpg"
const IMAGE_SCALE := 2.0
const BACKDROP_COLOR := Color(0.05, 0.07, 0.09)
const HINT_TEXT := "点击任意位置进入"
const HINT_FONT_SIZE := 34
const HINT_COLOR := Color(0.92, 0.92, 0.86)
const HINT_BOTTOM_MARGIN := 116.0
const HINT_HEIGHT := 50.0

var _dismissed := false
var _cover: TextureRect = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 吃掉鼠标事件避免穿透到下层；键盘事件仍走 _unhandled_input
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## 封面贴图是否加载成功（供校验与排查使用）
func has_cover_texture() -> bool:
	return _cover != null and _cover.texture != null


## 确认进入：重复调用只生效一次（鼠标与键盘可能同时触发）
func dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true
	dismissed.emit()


func _build() -> void:
	_add_backdrop()
	_add_cover()
	_add_hint()


func _add_backdrop() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOR
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)


func _add_cover() -> void:
	_cover = UiKit.make_texture(IMAGE_PATH)
	# make_texture 默认铺满父容器，这里改回左上锚点后按等比尺寸居中摆放
	_cover.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var canvas := Vector2(GameConfig.CANVAS_W, GameConfig.CANVAS_H)
	if _cover.texture != null:
		_cover.size = _cover.texture.get_size() * IMAGE_SCALE
	else:
		_cover.size = Vector2.ZERO
	_cover.position = (canvas - _cover.size) * 0.5
	add_child(_cover)


func _add_hint() -> void:
	var hint := UiKit.make_label(HINT_TEXT, HINT_FONT_SIZE, HINT_COLOR)
	hint.position = Vector2(0.0, GameConfig.CANVAS_H - HINT_BOTTOM_MARGIN)
	hint.size = Vector2(GameConfig.CANVAS_W, HINT_HEIGHT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func _gui_input(event: InputEvent) -> void:
	if _is_dismiss_event(event):
		dismiss()


func _unhandled_input(event: InputEvent) -> void:
	if _is_dismiss_event(event):
		dismiss()


## 左键按下或任意按键（排除长按回显）都算确认
func _is_dismiss_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo
	return false