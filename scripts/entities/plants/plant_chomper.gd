class_name PlantChomper
extends PlantBase
## 食人花：一口吞噬前方僵尸（无视顶具），随后进入消化休息

const CHEW_TIME := 1.1

enum E_State { Idle, Chewing, Digestion }

var _state: E_State = E_State.Idle
var _timer := 0.0


func _anim_sheets() -> Dictionary:
	return {"idle": "chomper_idle", "attack": "chomper_attack"}


func _on_planted() -> void:
	if sprite != null:
		sprite.play("idle")


## 单局快照：吞噬状态机与计时器
func snapshot_state() -> Dictionary:
	return {"state": int(_state), "t": _timer}


func restore_state(data: Dictionary) -> void:
	_state = _state_from_int(int(data.get("state", 0)))
	_timer = float(data.get("t", 0.0))
	if sprite == null:
		return
	if _state == E_State.Chewing:
		sprite.play("attack")
	elif _state == E_State.Digestion:
		sprite.play("idle")


## 整数还原枚举（避免非法值写坏状态机）
func _state_from_int(value: int) -> E_State:
	match value:
		1:
			return E_State.Chewing
		2:
			return E_State.Digestion
		_:
			return E_State.Idle


func _tick(delta: float) -> void:
	if _state == E_State.Idle:
		_try_eat()
		return

	_timer -= delta
	if _timer > 0.0:
		return
	if _state == E_State.Chewing:
		_state = E_State.Digestion
		_timer = float(GameConfig.PLANT_BEHAVIOR["chomper"]["rest_time"])
		if sprite != null:
			sprite.play("idle")
	else:
		_state = E_State.Idle


func _try_eat() -> void:
	var trigger := float(GameConfig.PLANT_BEHAVIOR["chomper"]["trigger_x"])
	for zombie in lane_zombies():
		if not zombie.can_be_hit():
			continue
		var distance := zombie.position.x - position.x
		if distance <= 0.0 or distance > trigger:
			continue
		_eat(zombie)
		return


func _eat(zombie: ZombieBase) -> void:
	_state = E_State.Chewing
	_timer = CHEW_TIME
	if sprite != null:
		sprite.play("attack")
	play_sfx("chomp")
	zombie.kill_directly()