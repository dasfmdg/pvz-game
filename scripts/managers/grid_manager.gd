class_name GridManager
extends Node2D
## 格子与种植：占用表、悬停高亮、种植 / 铲除、僵尸啃食查询
## 只有这里能改写格子占用状态，避免多处状态漂移

const Z_LAYER := 12
const GHOST_ALPHA := 0.55

var game: MainGameManager = null
var selected_plant_id := ""
var is_shovel_mode := false
var hover_cell := Vector2i(-1, -1)

var _occupied: Dictionary = {}
var _ghost: AnimatedSprite2D = null


func setup(game_ref: MainGameManager) -> void:
	game = game_ref
	z_index = Z_LAYER
	EventBus.card_selected.connect(_on_card_selected)
	EventBus.card_selection_cleared.connect(_on_selection_cleared)
	EventBus.shovel_selected.connect(_on_shovel_selected)
	EventBus.plant_removed.connect(_on_plant_removed)


func _process(_delta: float) -> void:
	_update_hover()


# ---------------- 查询 ----------------
func is_free(cell: Vector2i) -> bool:
	var plant: PlantBase = _occupied.get(cell, null)
	return plant == null or not is_instance_valid(plant)


func plant_at(cell: Vector2i) -> PlantBase:
	var plant: PlantBase = _occupied.get(cell, null)
	if plant != null and not is_instance_valid(plant):
		_occupied.erase(cell)
		return null
	return plant


func occupied_count() -> int:
	return _occupied.size()


## 僵尸嘴部位置 bite_x 落在哪株植物的受击区间内
func find_eatable_plant(lane: int, bite_x: float) -> PlantBase:
	for col in GameConfig.COLS:
		var plant := plant_at(Vector2i(col, lane))
		if plant == null or not plant.is_eatable():
			continue
		var span := plant.bite_span()
		if bite_x >= span.x and bite_x <= span.y:
			return plant
	return null


# ---------------- 种植 / 铲除 ----------------
func place_plant(plant_id: String, cell: Vector2i) -> bool:
	if not GameConfig.is_valid_cell(cell) or not is_free(cell):
		return false
	var cost := GameConfig.plant_cost(plant_id)
	if not game.try_spend_sun(cost):
		return false
	var plant := PlantFactory.create(plant_id)
	if plant == null:
		game.add_sun(cost)
		return false
	plant.setup(plant_id, cell, game)
	_occupied[cell] = plant
	game.plants_root.add_child(plant)
	game.play_sfx("plant")
	EventBus.plant_placed.emit(plant_id, cell)
	EventBus.card_used.emit(plant_id)
	return true


func try_plant_at(world_pos: Vector2) -> bool:
	if selected_plant_id.is_empty() or is_shovel_mode:
		return false
	var cell := GameConfig.point_to_cell(world_pos)
	if not GameConfig.is_valid_cell(cell) or not is_free(cell):
		return false
	if game.sun < GameConfig.plant_cost(selected_plant_id):
		return false
	return place_plant(selected_plant_id, cell)


func try_shovel_at(world_pos: Vector2) -> bool:
	if not is_shovel_mode:
		return false
	var cell := GameConfig.point_to_cell(world_pos)
	if not GameConfig.is_valid_cell(cell):
		return false
	var plant := plant_at(cell)
	if plant == null:
		return false
	plant.vanish()
	EventBus.card_selection_cleared.emit()
	return true


func clear_selection() -> void:
	EventBus.card_selection_cleared.emit()


# ---------------- 手持与高亮 ----------------
func _on_card_selected(plant_id: String) -> void:
	selected_plant_id = plant_id
	is_shovel_mode = false
	_build_ghost(plant_id)


func _on_shovel_selected() -> void:
	selected_plant_id = ""
	is_shovel_mode = true
	_clear_ghost()
	queue_redraw()


func _on_selection_cleared() -> void:
	selected_plant_id = ""
	is_shovel_mode = false
	_clear_ghost()
	set_hover(Vector2i(-1, -1))


func _on_plant_removed(cell: Vector2i) -> void:
	_occupied.erase(cell)
	queue_redraw()


func _build_ghost(plant_id: String) -> void:
	_clear_ghost()
	var data := GameConfig.plant_data(plant_id)
	if data.is_empty():
		return
	_ghost = SpriteLibrary.make_sprite({"main": String(data["sheet"])},
			float(data["dw"]), float(data["dh"]))
	_ghost.modulate.a = GHOST_ALPHA
	_ghost.visible = false
	add_child(_ghost)
	queue_redraw()


func _clear_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


func _update_hover() -> void:
	var holding := is_shovel_mode or not selected_plant_id.is_empty()
	if not holding:
		set_hover(Vector2i(-1, -1))
		return
	var cell := GameConfig.point_to_cell(get_global_mouse_position())
	set_hover(cell if GameConfig.is_valid_cell(cell) else Vector2i(-1, -1))


func set_hover(cell: Vector2i) -> void:
	if cell == hover_cell:
		return
	hover_cell = cell
	var valid := GameConfig.is_valid_cell(cell)
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.visible = valid and not is_shovel_mode
		if valid:
			_ghost.position = GameConfig.cell_center(cell)
	queue_redraw()


func _draw() -> void:
	if selected_plant_id.is_empty() and not is_shovel_mode:
		return
	for row in GameConfig.ROWS:
		for col in GameConfig.COLS:
			draw_rect(_cell_rect(Vector2i(col, row)), Color(1, 1, 1, 0.06))
	if not GameConfig.is_valid_cell(hover_cell):
		return
	var color := Color(1, 1, 1, 0.4)
	if is_shovel_mode:
		color = Color(1, 0.55, 0.2, 0.5) if plant_at(hover_cell) != null else Color(1, 1, 1, 0.15)
	elif not is_free(hover_cell):
		color = Color(1, 0.25, 0.2, 0.45)
	draw_rect(_cell_rect(hover_cell), color, false, 5.0)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		GameConfig.GRID_X + float(cell.x) * GameConfig.CELL_W,
		GameConfig.GRID_Y + float(cell.y) * GameConfig.CELL_H,
		GameConfig.CELL_W,
		GameConfig.CELL_H
	)