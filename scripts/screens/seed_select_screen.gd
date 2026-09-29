class_name SeedSelectScreen
extends Control
## 选卡界面：上方展示本关会出现的僵尸种类，下方从已解锁植物中挑卡（不超过槽位上限）
## 第 7 关起由 MainRouter 在进关前插入本界面；第 1~6 关仍直接进关

## 裸 Array（TypedArray 作信号参数兼容性不稳）
signal start_pressed(plants: Array)
signal back_pressed()

const TITLE_TOP := 30.0
const LEVEL_NAME_TOP := 114.0
const ZOMBIE_TITLE_TOP := 172.0
const ZOMBIE_TILE_W := 152.0
const ZOMBIE_TILE_H := 168.0
const ZOMBIE_TILE_GAP := 18.0
const ZOMBIE_ROW_TOP := 216.0
const PLANT_TITLE_TOP := 400.0
const CARD_TOP := 448.0
const CARD_GAP := 20.0
const PICKED_TITLE_TOP := 650.0
const PICKED_ROW_TOP := 698.0
const PICKED_GAP := 8.0
const COUNT_TOP := 856.0
const HINT_TOP := 888.0
const BUTTON_TOP := 930.0
const BUTTON_W := 300.0
const BUTTON_H := 88.0
const BACK_BUTTON_X := 640.0
const START_BUTTON_X := 980.0

const PICK_HINT_TEXT := "点击卡片选择或取消"
const FULL_HINT_TEXT := "槽位已满，请先取消一张"

var level_index := 0
var slot_limit := 0
var available_plants: Array[String] = []
var zombies: Array[String] = []
var picked: Array[String] = []

var cards: Array[SeedCard] = []
var zombie_tiles: Array[Control] = []
var picked_tiles: Array[CardItem] = []
var count_label: Label = null
var hint_label: Label = null
var start_button: Button = null
var back_button: Button = null

## 已选预览条按植物懒创建的池（避免重复 setup 造成子节点堆积）
var _picked_pool: Dictionary = {}
var _confirmed := false


## 装载关卡数据（须在加入场景树前调用）；preset_plants 为上次同关的选卡结果
func setup(level_index_value: int, preset_plants: Array = []) -> void:
	level_index = clampi(level_index_value, 0, GameConfig.LEVELS.size() - 1)
	slot_limit = GameConfig.seed_slot_limit(level_index + 1)
	available_plants = GameConfig.plants_for_level(level_index + 1)
	zombies = GameConfig.zombies_for_level(level_index)
	picked = _resolve_picked(preset_plants)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_refresh_state()


# ---------------- 选卡交互 ----------------
## 已选 → 取消；未选且未满 → 追加；槽位满或不在可选表 → 返回 false（状态不变）
func toggle_plant(plant_id: String) -> bool:
	if picked.has(plant_id):
		picked.erase(plant_id)
		_refresh_state()
		return true
	if not available_plants.has(plant_id) or picked.size() >= slot_limit:
		return false
	picked.append(plant_id)
	_refresh_state()
	return true


# ---------------- 构建 ----------------
func _build() -> void:
	add_child(UiKit.make_texture("res://assets/ui/levelmenu.png"))
	var mask := ColorRect.new()
	mask.color = Color(0.05, 0.08, 0.05, 0.62)
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mask)

	_add_centered_label("选择你的卡片", 64, Color(0.98, 0.94, 0.5), TITLE_TOP, 84.0)
	_add_centered_label(String(GameConfig.level_data(level_index).get("name", "")), 32,
			Color(1.0, 1.0, 0.92), LEVEL_NAME_TOP, 44.0)
	_add_centered_label("本关僵尸种类", 28, Color(0.95, 0.85, 0.6), ZOMBIE_TITLE_TOP, 40.0)

	_build_zombie_row()

	_add_centered_label("选择携带的植物（槽位上限 %d 张）" % slot_limit, 28,
			Color(0.95, 0.85, 0.6), PLANT_TITLE_TOP, 40.0)
	_build_card_row()

	_add_centered_label("已选卡片", 28, Color(0.95, 0.85, 0.6), PICKED_TITLE_TOP, 40.0)

	count_label = _add_centered_label("", 24, Color(1.0, 1.0, 0.9), COUNT_TOP, 34.0)
	hint_label = _add_centered_label("", 22, Color(0.9, 0.95, 0.85), HINT_TOP, 34.0)

	back_button = _make_action_button("返回", BACK_BUTTON_X)
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	start_button = _make_action_button("开始游戏", START_BUTTON_X)
	start_button.pressed.connect(_on_start)


func _build_zombie_row() -> void:
	var origin_x := _row_origin_x(zombies.size(), ZOMBIE_TILE_W, ZOMBIE_TILE_GAP)
	for i in zombies.size():
		var tile := _make_zombie_tile(zombies[i])
		tile.position = Vector2(origin_x + float(i) * (ZOMBIE_TILE_W + ZOMBIE_TILE_GAP),
				ZOMBIE_ROW_TOP)
		add_child(tile)
		zombie_tiles.append(tile)


func _make_zombie_tile(zombie_id: String) -> Control:
	var tile := Control.new()
	tile.custom_minimum_size = Vector2(ZOMBIE_TILE_W, ZOMBIE_TILE_H)
	tile.size = Vector2(ZOMBIE_TILE_W, ZOMBIE_TILE_H)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := ColorRect.new()
	background.color = Color(0.10, 0.14, 0.08, 0.9)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	tile.add_child(background)

	var walk_sheet := String(GameConfig.zombie_data(zombie_id).get("walk", ""))
	var art := TextureRect.new()
	art.texture = UiKit.zombie_portrait(zombie_id, walk_sheet)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2(0.0, 6.0)
	art.size = Vector2(ZOMBIE_TILE_W, ZOMBIE_TILE_H - 48.0)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(art)

	var name_label := UiKit.make_label(GameConfig.zombie_name_cn(zombie_id), 24,
			Color(0.98, 0.95, 0.7))
	name_label.position = Vector2(0.0, ZOMBIE_TILE_H - 42.0)
	name_label.size = Vector2(ZOMBIE_TILE_W, 38.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add_child(name_label)
	return tile


func _build_card_row() -> void:
	var origin_x := _row_origin_x(available_plants.size(), SeedCard.CARD_W, CARD_GAP)
	for i in available_plants.size():
		var card := SeedCard.new()
		card.setup(available_plants[i])
		card.position = Vector2(origin_x + float(i) * (SeedCard.CARD_W + CARD_GAP), CARD_TOP)
		card.card_pressed.connect(func(plant_id: String) -> void: toggle_plant(plant_id))
		add_child(card)
		cards.append(card)


func _add_centered_label(text: String, font_size: int, color: Color, top: float,
		height: float) -> Label:
	var label := UiKit.make_label(text, font_size, color)
	label.position = Vector2(0.0, top)
	label.size = Vector2(GameConfig.CANVAS_W, height)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func _make_action_button(text: String, left: float) -> Button:
	var button := UiKit.make_button(text, 34)
	button.custom_minimum_size = Vector2(BUTTON_W, BUTTON_H)
	button.size = Vector2(BUTTON_W, BUTTON_H)
	button.position = Vector2(left, BUTTON_TOP)
	add_child(button)
	return button


func _row_origin_x(count: int, item_w: float, gap: float) -> float:
	if count <= 0:
		return GameConfig.CANVAS_W * 0.5
	var total := item_w * float(count) + gap * float(count - 1)
	return (GameConfig.CANVAS_W - total) * 0.5


# ---------------- 状态刷新 ----------------
func _refresh_state() -> void:
	for card in cards:
		var order := picked.find(card.plant_id)
		card.set_picked(order >= 0, order + 1)
		card.set_dimmed(order < 0 and picked.size() >= slot_limit)
	_refresh_picked_row()
	if count_label != null:
		count_label.text = "已选 %d / %d 张" % [picked.size(), slot_limit]
	if hint_label != null:
		hint_label.text = FULL_HINT_TEXT if picked.size() >= slot_limit else PICK_HINT_TEXT
	if start_button != null:
		start_button.disabled = picked.is_empty()


## 已选预览条：按选卡顺序重新摆位，未选中的池中卡隐藏
func _refresh_picked_row() -> void:
	picked_tiles.clear()
	var origin_x := _row_origin_x(slot_limit, CardItem.CARD_W, PICKED_GAP)
	for i in picked.size():
		var tile := _take_picked_tile(picked[i])
		tile.position = Vector2(origin_x + float(i) * (CardItem.CARD_W + PICKED_GAP),
				PICKED_ROW_TOP)
		tile.visible = true
		picked_tiles.append(tile)
	for raw_id in _picked_pool.keys():
		var tile: CardItem = _picked_pool[raw_id]
		if not picked.has(String(raw_id)):
			tile.visible = false


func _take_picked_tile(plant_id: String) -> CardItem:
	if _picked_pool.has(plant_id):
		return _picked_pool[plant_id]
	var tile := CardItem.new()
	tile.setup(plant_id)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.visible = false
	add_child(tile)
	_picked_pool[plant_id] = tile
	return tile


## 预设选卡：上次结果优先（越权 / 重复 / 超额丢弃）；为空则取解锁表前 slot_limit 张
func _resolve_picked(preset_plants: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_id in preset_plants:
		if result.size() >= slot_limit:
			break
		var plant_id := String(raw_id)
		if available_plants.has(plant_id) and not result.has(plant_id):
			result.append(plant_id)
	if not result.is_empty():
		return result
	for plant_id in available_plants:
		if result.size() >= slot_limit:
			break
		result.append(plant_id)
	return result


func _on_start() -> void:
	if _confirmed or picked.is_empty():
		return
	_confirmed = true
	start_pressed.emit(picked.duplicate())