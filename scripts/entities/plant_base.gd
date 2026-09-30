class_name PlantBase
extends Node2D
## 植物基类：精灵装配、生命与受击、通用生命周期
## 具体行为由子类重写 _tick() / _on_planted() / _anim_sheets()
## 参考工程对应：scripts/character/character_000_base.gd（组件化 → 本工程简化为模板方法）

const DEATH_FADE_TIME := 0.35

var plant_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var max_hp: int = 300
var hp: int = 300
var is_dead := false
var draw_size := Vector2.ZERO

var game: MainGameManager = null
var sprite: AnimatedSprite2D = null


# ---------------- 子类可重写的钩子 ----------------
## 动画集合：{ 动画名: 精灵表名 }
func _anim_sheets() -> Dictionary:
	return {"main": String(GameConfig.plant_data(plant_id)["sheet"])}


## 只播放一次的动画名（默认全部循环）
func _once_anims() -> Array:
	return []


## 种植完成（精灵已装配）
func _on_planted() -> void:
	pass


## 每帧行为（暂停 / 结束时不会被调用）
func _tick(_delta: float) -> void:
	pass


# ---------------- 单局快照钩子（子类按需重写，存自己的私有计时器 / 状态） ----------------
## 私有状态序列化；基类无状态，返回空字典
func snapshot_state() -> Dictionary:
	return {}


## 私有状态恢复；对 sprite 的操作需自行判空（add_child 后 sprite 才存在）
func restore_state(_data: Dictionary) -> void:
	pass


# ---------------- 生命周期 ----------------
func setup(plant_id_value: String, cell_value: Vector2i, game_ref: MainGameManager) -> void:
	plant_id = plant_id_value
	cell = cell_value
	game = game_ref
	var data := GameConfig.plant_data(plant_id)
	max_hp = int(data.get("hp", 300))
	hp = max_hp
	draw_size = Vector2(float(data.get("dw", 100.0)), float(data.get("dh", 100.0)))
	position = GameConfig.cell_center(cell)


func _ready() -> void:
	sprite = SpriteLibrary.make_sprite(_anim_sheets(), draw_size.x, draw_size.y, _once_anims())
	add_child(sprite)
	_on_planted()


func _process(delta: float) -> void:
	if is_dead or game == null or not game.is_running():
		return
	_tick(delta)


func get_lane() -> int:
	return cell.y


## 僵尸啃食判定区间（植物被啃的横向范围）
func bite_span() -> Vector2:
	return Vector2(position.x - 46.0, position.x + 46.0)


func is_eatable() -> bool:
	return not is_dead


func hp_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)


# ---------------- 受击与死亡 ----------------
func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	hp = maxi(0, hp - amount)
	if hp <= 0:
		die()


## 正常死亡：淡出后销毁
func die() -> void:
	if is_dead:
		return
	is_dead = true
	_notify_removed()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, DEATH_FADE_TIME)
	tween.tween_callback(queue_free)


## 立即消失（炸弹类植物引爆后使用）
func vanish() -> void:
	if is_dead:
		return
	is_dead = true
	_notify_removed()
	queue_free()


func _notify_removed() -> void:
	EventBus.plant_removed.emit(cell)


# ---------------- 便捷查询 ----------------
## 同行的存活僵尸（默认返回全部，子类按需过滤）
func lane_zombies() -> Array[ZombieBase]:
	if game == null:
		return []
	return game.zombies_in_lane(cell.y)


func play_sfx(sound: String) -> void:
	if game != null:
		game.play_sfx(sound)