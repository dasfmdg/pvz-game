class_name PlantSquash
extends PlantBase
## 倭瓜：僵尸靠近时跃起压扁，对落点范围造成巨量伤害

const CRUSH_RADIUS := 110.0
const JUMP_TIME := 0.55

enum E_State { Idle, Jumping, Done }

var _state: E_State = E_State.Idle


func _anim_sheets() -> Dictionary:
	return {"idle": "squash_idle", "attack": "squash_attack"}


func _on_planted() -> void:
	if sprite != null:
		sprite.play("idle")


## 单局快照：跃起状态机（Jumping 由补间驱动，无法从存档续播，读档时退回 Idle 重新判定）
func snapshot_state() -> Dictionary:
	return {"state": int(_state)}


func restore_state(data: Dictionary) -> void:
	var raw := int(data.get("state", 0))
	_state = E_State.Done if raw == 2 else E_State.Idle
	if sprite != null and _state == E_State.Idle:
		sprite.play("idle")


func _tick(_delta: float) -> void:
	if _state != E_State.Idle:
		return
	var trigger := float(GameConfig.PLANT_BEHAVIOR["squash"]["trigger_x"])
	for zombie in lane_zombies():
		if not zombie.can_be_hit():
			continue
		if absf(zombie.position.x - position.x) <= trigger:
			_attack(zombie)
			return


func _attack(zombie: ZombieBase) -> void:
	_state = E_State.Jumping
	if sprite != null:
		sprite.play("attack")
	var target := Vector2(zombie.position.x, zombie.position.y - 40.0)
	var tween := create_tween()
	tween.tween_property(self, "position", target, JUMP_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_crush.bind(target))


func _crush(target: Vector2) -> void:
	if is_dead:
		return
	_state = E_State.Done
	var damage := int(GameConfig.PLANT_BEHAVIOR["squash"]["damage"])
	game.damage_zombies_near(target, CRUSH_RADIUS, damage)
	play_sfx("cherrybomb")
	vanish()