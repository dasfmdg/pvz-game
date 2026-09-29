class_name MenuScreen
extends Control
## 主菜单：背景 + 标题 + 「开始游戏 / 植物图鉴 / 设置 / 退出」

signal start_pressed()
signal almanac_pressed()
signal settings_pressed()
signal quit_pressed()

const PANEL_W := 460.0
const BUTTON_H := 92.0

var buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	add_child(UiKit.make_texture("res://assets/ui/menu_bg.png"))

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


func _add_button(parent: Node, text: String, target: Signal) -> Button:
	var button := UiKit.make_button(text, 40)
	button.custom_minimum_size = Vector2(PANEL_W, BUTTON_H)
	button.pressed.connect(func() -> void: target.emit())
	parent.add_child(button)
	return button