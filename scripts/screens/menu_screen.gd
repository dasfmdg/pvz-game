class_name MenuScreen
extends Control
## 主菜单：整页背景（原版主页图，等比铺满画布高，两侧深色底）
##        + 左上角告示牌中间显示玩家名字（名字先占位，后续接存档/登录）
##        + 标题 + 「开始游戏 / 植物图鉴 / 设置 / 退出」

signal start_pressed()
signal almanac_pressed()
signal settings_pressed()
signal quit_pressed()

const PANEL_W := 460.0
const BUTTON_H := 92.0

## 整页背景：原图 512×384（4:3），按画布高度等比放大居中，不拉伸，两侧留深色底
const PAGE_IMAGE_PATH := "res://assets/ui/menu_page.jpg"
const PAGE_SOURCE_SIZE := Vector2(512.0, 384.0)
const PAGE_BACKDROP_COLOR := Color(0.05, 0.07, 0.09)

## 告示牌名字行：原图自带的 3T! 用同牌子的干净木纹盖住后再写名字
## 木纹贴图 sign_wood.png 即取自原图 Rect2(140, 61, 28, 13)，与遮挡区同尺寸，1:1 贴上去不产生拉伸
const SIGN_WOOD_PATH := "res://assets/ui/sign_wood.png"
const SIGN_NAME_ORIGIN := Vector2(96.0, 61.0)
const SIGN_NAME_SIZE := Vector2(28.0, 13.0)

## 玩家名字（占位）：等接入存档 / 登录后改为读取真实昵称
const PLAYER_NAME := "玩家"
const PLAYER_NAME_FONT_SIZE := 28
const PLAYER_NAME_COLOR := Color(0.94, 0.91, 0.8)

var buttons: Dictionary = {}
## 告示牌上的名字标签（供校验使用）
var name_label: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	_add_page_background()
	_add_player_name()

	var title := UiKit.make_label("植物大战僵尸", 104, Color(0.98, 0.94, 0.5))
	title.position = Vector2(0.0, 110.0)
	title.size = Vector2(GameConfig.CANVAS_W, 130.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var subtitle := UiKit.make_label("Godot 4.6 复刻版", 34, Color(0.95, 0.95, 0.9))
	subtitle.position = Vector2(0.0, 250.0)
	subtitle.size = Vector2(GameConfig.CANVAS_W, 50.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	box.position = Vector2(GameConfig.CANVAS_W * 0.5 - PANEL_W * 0.5, 460.0)
	box.size = Vector2(PANEL_W, 4.0 * BUTTON_H + 3.0 * 26.0)
	add_child(box)

	buttons["start"] = _add_button(box, "开始游戏", start_pressed)
	buttons["almanac"] = _add_button(box, "植物图鉴", almanac_pressed)
	buttons["settings"] = _add_button(box, "设置", settings_pressed)
	var quit_button := _add_button(box, "退出", quit_pressed)
	buttons["quit"] = quit_button
	# Web 导出下无意义，直接隐藏
	if OS.has_feature("web"):
		quit_button.visible = false


# ---------------- 整页背景 ----------------
## 深色底 + 等比居中的主页图；只有背景图参与缩放，界面控件位置不受影响
func _add_page_background() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = PAGE_BACKDROP_COLOR
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var page := UiKit.make_texture(PAGE_IMAGE_PATH)
	# make_texture 默认铺满父容器，这里改回左上锚点后按等比尺寸居中摆放
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.size = PAGE_SOURCE_SIZE * page_scale()
	page.position = page_origin()
	add_child(page)


## 背景缩放比：按画布高度铺满
func page_scale() -> float:
	return GameConfig.CANVAS_H / PAGE_SOURCE_SIZE.y


## 背景左上角坐标：水平居中，两侧等宽留深色底
func page_origin() -> Vector2:
	var page_width := PAGE_SOURCE_SIZE.x * page_scale()
	return Vector2((GameConfig.CANVAS_W - page_width) * 0.5, 0.0)


# ---------------- 告示牌玩家名字 ----------------
## 先用同牌子的干净木纹盖住原图自带的名字，再把占位名字居中写上
func _add_player_name() -> void:
	var origin := _to_canvas(SIGN_NAME_ORIGIN)
	var area_size := SIGN_NAME_SIZE * page_scale()

	var wood := UiKit.make_texture(SIGN_WOOD_PATH)
	wood.set_anchors_preset(Control.PRESET_TOP_LEFT)
	wood.size = area_size
	wood.position = origin
	add_child(wood)

	name_label = UiKit.make_label(PLAYER_NAME, PLAYER_NAME_FONT_SIZE, PLAYER_NAME_COLOR)
	# 标签宽度取遮挡区两倍并左移半格，使文字水平居中于牌面
	name_label.size = Vector2(area_size.x * 2.0, area_size.y)
	name_label.position = Vector2(origin.x - area_size.x * 0.5, origin.y)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(name_label)


## 原图像素坐标 → 画布坐标（与背景同一套缩放与偏移）
func _to_canvas(source_pos: Vector2) -> Vector2:
	return page_origin() + source_pos * page_scale()


func _add_button(parent: Node, text: String, target: Signal) -> Button:
	var button := UiKit.make_button(text, 40)
	button.custom_minimum_size = Vector2(PANEL_W, BUTTON_H)
	button.pressed.connect(func() -> void: target.emit())
	parent.add_child(button)
	return button