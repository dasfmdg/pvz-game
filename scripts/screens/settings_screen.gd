class_name SettingsScreen
extends Control
## 设置：BGM / 音效 音量滑条（0~100）与静音开关，实时写入 SaveManager

signal back_pressed()

const ROW_X := 560.0
const ROW_W := 800.0
const SLIDER_W := 480.0

var bgm_slider: HSlider = null
var sfx_slider: HSlider = null
var mute_check: CheckButton = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	add_child(UiKit.make_texture("res://assets/ui/menu_bg.png"))

	var title := UiKit.make_label("设置", 72, Color(0.98, 0.94, 0.5))
	title.position = Vector2(0.0, 90.0)
	title.size = Vector2(GameConfig.CANVAS_W, 100.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	bgm_slider = _build_volume_row("背景音乐", 320.0, SaveManager.bgm_volume)
	bgm_slider.value_changed.connect(_on_bgm_changed)

	sfx_slider = _build_volume_row("音效", 440.0, SaveManager.sfx_volume)
	sfx_slider.value_changed.connect(_on_sfx_changed)

	var mute_label := UiKit.make_label("静音", 36, Color(1.0, 1.0, 0.92))
	mute_label.position = Vector2(ROW_X, 560.0)
	mute_label.size = Vector2(240.0, 50.0)
	add_child(mute_label)

	mute_check = CheckButton.new()
	mute_check.position = Vector2(ROW_X + 260.0, 556.0)
	mute_check.size = Vector2(120.0, 56.0)
	mute_check.focus_mode = Control.FOCUS_NONE
	mute_check.button_pressed = SaveManager.muted
	mute_check.toggled.connect(_on_mute_toggled)
	add_child(mute_check)

	var back := UiKit.make_button("返回主菜单", 32)
	back.custom_minimum_size = Vector2(300.0, 80.0)
	back.position = Vector2(GameConfig.CANVAS_W * 0.5 - 150.0, GameConfig.CANVAS_H - 150.0)
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)


## 一行「标签 + 滑条」，返回滑条供外部连接
func _build_volume_row(text: String, y: float, value: float) -> HSlider:
	var label := UiKit.make_label(text, 36, Color(1.0, 1.0, 0.92))
	label.position = Vector2(ROW_X, y)
	label.size = Vector2(240.0, 50.0)
	add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.position = Vector2(ROW_X + 260.0, y + 4.0)
	slider.custom_minimum_size = Vector2(SLIDER_W, 42.0)
	slider.size = Vector2(SLIDER_W, 42.0)
	slider.focus_mode = Control.FOCUS_NONE
	slider.set_value_no_signal(clampf(value, 0.0, 1.0) * 100.0)
	add_child(slider)
	return slider


# ---------------- 事件 ----------------
func _on_bgm_changed(value: float) -> void:
	SaveManager.set_setting("bgm_volume", value / 100.0)


func _on_sfx_changed(value: float) -> void:
	SaveManager.set_setting("sfx_volume", value / 100.0)


func _on_mute_toggled(pressed: bool) -> void:
	SaveManager.set_setting("muted", pressed)