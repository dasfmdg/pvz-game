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