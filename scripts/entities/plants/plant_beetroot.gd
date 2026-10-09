class_name PlantBeetroot
extends PlantBase
## 甜菜：沿本行发射可穿透整行的甜菜弹，命中后弹体继续前进（同一僵尸只结算一次）
## 死亡时先播完枯萎动画再淡出，与其它植物的直接淡出区分

var _timer := 0.0
var _behavior: Dictionary = {}


func _anim_sheets() -> Dictionary:
	return {"main": "beetroot", "dying": "beetroot_dying"}


func _once_anims() -> Array:
	return ["dying"]


func _on_planted() -> void:
	_behavior = GameConfig.PLANT_BEHAVIOR.get(plant_id, {})
	_timer = float(_behavior.get("first_fire", 0.8))


# ---------------- 单局快照 ----------------
func snapshot_state() -> Dictionary:
	return {"t": _timer}


func restore_state(data: Dictionary) -> void:
	_timer = float(data.get("t", _timer))


# ---------------- 行为 ----------------
func _tick(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if not _has_target():
		return
	_timer = float(_behavior.get("fire_interval", 2.0))
	game.spawn_beet_bullet(cell.y, position.x + float(_behavior.get("muzzle_offset", 34.0)),
			GameConfig.cell_center_y(cell.y), int(_behavior.get("damage", 45)))


## 本行前方存在可命中的僵尸才开火
func _has_target() -> bool:
	for zombie in lane_zombies():
		if zombie.position.x > position.x:
			return true
	return false


# ---------------- 死亡 ----------------
## 枯萎：先播完枯萎动画，再淡出销毁
func die() -> void:
	if is_dead:
		return
	is_dead = true
	_notify_removed()
	if sprite == null or not sprite.sprite_frames.has_animation("dying"):
		_fade_out()
		return
	sprite.play("dying")
	sprite.animation_finished.connect(_fade_out, CONNECT_ONE_SHOT)


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, DEATH_FADE_TIME)
	tween.tween_callback(queue_free)
