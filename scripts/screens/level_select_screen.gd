class_name LevelSelectScreen
extends Control
## 关卡选择：5 个关卡预览（level1~5.png），未解锁显示锁图标且不可进入

signal level_chosen(index: int)
signal back_pressed()

const CARD_W := 320.0
const CARD_GAP := 26.0
const PREVIEW_H := 300.0

var level_buttons: Array[Button] = []
var level_icons: Array[TextureRect] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	add_child(UiKit.make_texture("res://assets/ui/levelmenu.png"))

	var title := UiKit.make_label("选择关卡", 72, Color(0.98, 0.94, 0.5))
	title.position = Vector2(0.0, 90.0)
	title.size = Vector2(GameConfig.CANVAS_W, 100.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_GAP)
	row.position = Vector2(
		(GameConfig.CANVAS_W - (CARD_W * 5.0 + CARD_GAP * 4.0)) * 0.5, 300.0)
	row.size = Vector2(CARD_W * 5.0 + CARD_GAP * 4.0, 520.0)
	add_child(row)

	for index in GameConfig.LEVELS.size():
		row.add_child(_build_card(index))

	var back := UiKit.make_button("返回主菜单", 32)
	back.custom_minimum_size = Vector2(300.0, 80.0)
	back.position = Vector2(GameConfig.CANVAS_W * 0.5 - 150.0, GameConfig.CANVAS_H - 140.0)
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)


func _build_card(index: int) -> VBoxContainer:
	var level: Dictionary = GameConfig.LEVELS[index]
	var unlocked := SaveManager.is_unlocked(index)

	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, 520.0)
	card.add_theme_constant_override("separation", 14)

	var preview := Control.new()
	preview.custom_minimum_size = Vector2(CARD_W, PREVIEW_H)
	card.add_child(preview)

	var art := TextureRect.new()
	art.texture = UiKit.load_texture("res://assets/ui/level%d.png" % (index + 1))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(art)

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	if not unlocked:
		icon.texture = UiKit.load_texture("res://assets/ui/lock.png")
		icon.visible = true
	elif SaveManager.is_cleared(index):
		icon.texture = UiKit.load_texture("res://assets/ui/unlocked.png")
		icon.visible = true
	preview.add_child(icon)
	level_icons.append(icon)

	var name_label := UiKit.make_label(String(level["name"]), 30, Color(1.0, 1.0, 0.92))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)

	var best := UiKit.make_label("最佳击杀：%d" % SaveManager.best_kills_of(index), 26,
			Color(0.9, 0.95, 0.85))
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(best)

	var button := UiKit.make_button("进入关卡" if unlocked else "未解锁", 32)
	button.custom_minimum_size = Vector2(CARD_W, 84.0)
	button.disabled = not unlocked
	button.pressed.connect(func() -> void: level_chosen.emit(index))
	card.add_child(button)
	level_buttons.append(button)
	return card