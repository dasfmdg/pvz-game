class_name AlmanacScreen
extends Control
## 植物图鉴：植物 / 僵尸两个分页，卡片展示名称、阳光、冷却、血量
## 植物卡 11 张、僵尸卡 6 张；无专属立绘时用卡片图或精灵表首帧兜底

signal back_pressed()

const CARD_W := 360.0
const CARD_H := 420.0
const CARD_GAP := 22.0
const COLUMNS := 4

## 有独立立绘的植物（其余走 card_*.png 兜底）
const PLANT_PAGES := {
	"sunflower": "page_sunflower",
	"peashooter": "page_peashooter",
	"repeater": "page_repeater",
	"wallnut": "page_wallnut",
	"cherrybomb": "page_cherrybomb",
	"jalapeno": "page_jalapeno",
}

var plant_cards: Array[Control] = []
var zombie_cards: Array[Control] = []

var _plant_page: ScrollContainer = null
var _zombie_page: ScrollContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	add_child(UiKit.make_texture("res://assets/ui/almanac_icon.png"))

	var title := UiKit.make_label("植物图鉴", 64, Color(0.98, 0.94, 0.5))
	title.position = Vector2(0.0, 60.0)
	title.size = Vector2(GameConfig.CANVAS_W, 90.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var plant_tab := UiKit.make_button("植物", 32)
	plant_tab.custom_minimum_size = Vector2(220.0, 76.0)
	plant_tab.position = Vector2(GameConfig.CANVAS_W * 0.5 - 240.0, 176.0)
	plant_tab.pressed.connect(func() -> void: _show_page(true))
	add_child(plant_tab)

	var zombie_tab := UiKit.make_button("僵尸", 32)
	zombie_tab.custom_minimum_size = Vector2(220.0, 76.0)
	zombie_tab.position = Vector2(GameConfig.CANVAS_W * 0.5 + 20.0, 176.0)
	zombie_tab.pressed.connect(func() -> void: _show_page(false))
	add_child(zombie_tab)

	_plant_page = _make_page()
	_build_plant_cards(_plant_page.get_child(0) as GridContainer)
	add_child(_plant_page)

	_zombie_page = _make_page()
	_build_zombie_cards(_zombie_page.get_child(0) as GridContainer)
	add_child(_zombie_page)

	_show_page(true)

	var back := UiKit.make_button("返回主菜单", 32)
	back.custom_minimum_size = Vector2(300.0, 80.0)
	back.position = Vector2(GameConfig.CANVAS_W * 0.5 - 150.0, GameConfig.CANVAS_H - 110.0)
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)


func _make_page() -> ScrollContainer:
	var page := ScrollContainer.new()
	page.position = Vector2((GameConfig.CANVAS_W - 1600.0) * 0.5, 280.0)
	page.size = Vector2(1600.0, 660.0)
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", int(CARD_GAP))
	grid.add_theme_constant_override("v_separation", int(CARD_GAP))
	page.add_child(grid)
	return page


func _show_page(is_plant: bool) -> void:
	if _plant_page != null:
		_plant_page.visible = is_plant
	if _zombie_page != null:
		_zombie_page.visible = not is_plant


# ---------------- 植物卡 ----------------
func _build_plant_cards(grid: GridContainer) -> void:
	for raw_id in GameConfig.PLANT_ORDER:
		var plant_id := String(raw_id)
		var data := GameConfig.plant_data(plant_id)
		var art := _plant_art(plant_id)
		var lines := [
			"阳光：%d" % int(data.get("cost", 0)),
			"冷却：%.1f 秒" % float(data.get("recharge", 0.0)),
			"血量：%d" % int(data.get("hp", 0)),
		]
		var card := _make_card(String(data.get("name", plant_id)), lines, art)
		grid.add_child(card)
		plant_cards.append(card)


func _plant_art(plant_id: String) -> Texture2D:
	if PLANT_PAGES.has(plant_id):
		var page_tex := UiKit.load_texture("res://assets/ui/%s.png" % PLANT_PAGES[plant_id])
		if page_tex != null:
			return page_tex
	return SpriteLibrary.card_texture(plant_id)


# ---------------- 僵尸卡 ----------------
func _build_zombie_cards(grid: GridContainer) -> void:
	for raw_id in GameConfig.ZOMBIES.keys():
		var zombie_id := String(raw_id)
		var data := GameConfig.zombie_data(zombie_id)
		# 立绘映射与兜底逻辑统一走 UiKit.zombie_portrait（与选卡界面共用一份）
		var art := UiKit.zombie_portrait(zombie_id, String(data.get("walk", "")))
		var lines := [
			"血量：%d" % int(data.get("hp", 0)),
			"速度：%.0f" % float(data.get("speed", 0.0)),
		]
		var card := _make_card(String(data.get("name", zombie_id)), lines, art)
		grid.add_child(card)
		zombie_cards.append(card)


# ---------------- 卡片外观 ----------------
func _make_card(title_text: String, lines: Array, art: Texture2D) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)

	var background := ColorRect.new()
	background.color = Color(0.10, 0.14, 0.08, 0.9)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(background)

	var frame := TextureRect.new()
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.texture = art
	frame.position = Vector2(20.0, 18.0)
	frame.size = Vector2(CARD_W - 40.0, 230.0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)

	var name_label := UiKit.make_label(title_text, 30, Color(0.98, 0.95, 0.7))
	name_label.position = Vector2(12.0, 252.0)
	name_label.size = Vector2(CARD_W - 24.0, 44.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)

	var y := 306.0
	for raw_line in lines:
		var line := UiKit.make_label(String(raw_line), 26, Color(0.95, 0.95, 0.9))
		line.position = Vector2(20.0, y)
		line.size = Vector2(CARD_W - 40.0, 34.0)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(line)
		y += 36.0
	return card