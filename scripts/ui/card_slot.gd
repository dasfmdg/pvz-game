class_name CardSlot
extends Control
## 卡槽：植物卡排布、选中与取消、冷却推进（暂停冻结）、铲子按钮

const CARD_GAP := 6.0
const SLOT_ORIGIN := Vector2(210.0, 14.0)
const SHOVEL_SIZE := Vector2(88.0, 122.0)
const SHOVEL_GAP := 18.0

var game: MainGameManager = null
var cards: Array[CardItem] = []
var shovel_button: Button = null
var selected_plant_id := ""


func setup(game_ref: MainGameManager) -> void:
	game = game_ref
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = SLOT_ORIGIN
	_build_cards()
	_build_shovel()
	EventBus.sun_changed.connect(_on_sun_changed)
	EventBus.card_used.connect(_on_card_used)
	EventBus.card_selection_cleared.connect(_on_selection_cleared)


func _process(delta: float) -> void:
	if game == null or not game.is_running():
		return
	for card in cards:
		card.tick(delta)


func _build_cards() -> void:
	for index in GameConfig.PLANT_ORDER.size():
		var plant_id: String = GameConfig.PLANT_ORDER[index]
		var card := CardItem.new()
		card.setup(plant_id)
		card.position = Vector2(float(index) * (CardItem.CARD_W + CARD_GAP), 0.0)
		card.card_pressed.connect(_on_card_pressed)
		add_child(card)
		cards.append(card)


func _build_shovel() -> void:
	shovel_button = Button.new()
	shovel_button.custom_minimum_size = SHOVEL_SIZE
	shovel_button.size = SHOVEL_SIZE
	shovel_button.position = Vector2(
		float(cards.size()) * (CardItem.CARD_W + CARD_GAP) + SHOVEL_GAP, 0.0)
	shovel_button.icon = SpriteLibrary.static_texture("shovel")
	shovel_button.expand_icon = true
	shovel_button.toggle_mode = true
	shovel_button.tooltip_text = "Shovel (dig up a plant)"
	shovel_button.pressed.connect(_on_shovel_pressed)
	add_child(shovel_button)


# ---------------- 选择逻辑 ----------------
func _on_card_pressed(plant_id: String) -> void:
	if game == null or game.is_over:
		return
	if selected_plant_id == plant_id:
		EventBus.card_selection_cleared.emit()
		return
	var card := card_for(plant_id)
	if card == null or not card.can_use():
		return
	if game.sun < GameConfig.plant_cost(plant_id):
		return
	selected_plant_id = plant_id
	_mark_selected(plant_id)
	if shovel_button != null:
		shovel_button.button_pressed = false
	EventBus.card_selected.emit(plant_id)


func _on_shovel_pressed() -> void:
	if game == null or game.is_over:
		return
	if shovel_button != null and shovel_button.button_pressed:
		selected_plant_id = ""
		_mark_selected("")
		EventBus.shovel_selected.emit()
		return
	EventBus.card_selection_cleared.emit()


func _on_selection_cleared() -> void:
	selected_plant_id = ""
	_mark_selected("")
	if shovel_button != null:
		shovel_button.button_pressed = false


func _on_card_used(plant_id: String) -> void:
	var card := card_for(plant_id)
	if card != null:
		card.start_cooldown()
	_on_selection_cleared()


func _on_sun_changed(value: int) -> void:
	refresh_affordability(value)


## 阳光变化时刷新卡片可用状态（阳光不足置灰）
func refresh_affordability(value: int) -> void:
	for card in cards:
		card.set_affordable(value >= card.cost)


func _mark_selected(plant_id: String) -> void:
	for card in cards:
		card.set_selected(card.plant_id == plant_id)


func card_for(plant_id: String) -> CardItem:
	for card in cards:
		if card.plant_id == plant_id:
			return card
	return null


func select_by_index(index: int) -> void:
	if index < 0 or index >= cards.size():
		return
	_on_card_pressed(cards[index].plant_id)