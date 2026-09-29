class_name LevelSelectScreen
extends Control
## 关卡选择：30 关滚动网格（1~5 关有立绘，其余关卡降级为编号底板）

signal level_chosen(index: int)
signal back_pressed()

const CARD_W := 320.0
const CARD_H := 470.0
const CARD_GAP := 26.0
const COLUMNS := 5
const PREVIEW_H := 220.0
const GRID_TOP := 230.0
const GRID_BOTTOM_MARGIN := 170.0

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

	var grid_width := CARD_W * COLUMNS + CARD_GAP * (COLUMNS - 1)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2((GameConfig.CANVAS_W - grid_width) * 0.5, GRID_TOP)
	scroll.size = Vector2(grid_width, GameConfig.CANVAS_H - GRID_TOP - GRID_BOTTOM_MARGIN)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", int(CARD_GAP))
	grid.add_theme_constant_override("v_separation", int(CARD_GAP))
	scroll.add_child(grid)

	for index in GameConfig.LEVELS.size():
		grid.add_child(_build_card(index))

	var back := UiKit.make_button("返回主菜单", 32)
	back.custom_minimum_size = Vector2(300.0, 80.0)
	back.position = Vector2(GameConfig.CANVAS_W * 0.5 - 150.0, GameConfig.CANVAS_H - 140.0)
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)


func _build_card(index: int) -> VBoxContainer:
	var level: Dictionary = GameConfig.LEVELS[index]
	var unlocked := SaveManager.is_unlocked(index)

	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.add_theme_constant_override("separation", 12)

	card.add_child(_build_preview(index, unlocked))

	var name_label := UiKit.make_label(String(level["name"]), 28, Color(1.0, 1.0, 0.92))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)

	var difficulty := UiKit.make_label("难度 %d" % int(level["difficulty"]), 24,
			Color(0.95, 0.85, 0.6))
	difficulty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(difficulty)

	var best := UiKit.make_label("最佳击杀：%d" % SaveManager.best_kills_of(index), 24,
			Color(0.9, 0.95, 0.85))
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(best)

	var button := UiKit.make_button("进入关卡" if unlocked else "未解锁", 30)
	button.custom_minimum_size = Vector2(CARD_W, 80.0)
	button.disabled = not unlocked
	button.pressed.connect(func() -> void: level_chosen.emit(index))
	card.add_child(button)
	level_buttons.append(button)
	return card


## 关卡预览：有立绘用立绘，没有则用深色底板 + 大号关卡编号兜底
func _build_preview(index: int, unlocked: bool) -> Control:
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(CARD_W, PREVIEW_H)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var art_path := "res://assets/ui/level%d.png" % (index + 1)
	if ResourceLoader.exists(art_path):
		var art := TextureRect.new()
		art.texture = UiKit.load_texture(art_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(art)
	else:
		var board := ColorRect.new()
		board.color = Color(0.10, 0.24, 0.13)
		board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(board)

		var number := UiKit.make_label(str(index + 1), 96, Color(0.95, 0.9, 0.55))
		number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		preview.add_child(number)

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
	return preview