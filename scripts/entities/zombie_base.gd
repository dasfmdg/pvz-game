class_name ZombieBase
extends Node2D
## 僵尸基类：行走 / 啃食 / 顶具护甲 / 破损外观 / 死亡（淡出或烧焦）
## 外观优先级：破损外观 > 无顶具外观 > 当前顶具外观
## 参考工程对应：scripts/character/zombie/zombie_000_base.gd（组件化 → 本工程用状态机简化）

enum E_State { Walk, Eat, Dying, Burnt }

const BITE_OFFSET := 26.0
const FROZEN_TINT := Color(0.62, 0.86, 1.0)
const BURNT_TINT := Color(0.35, 0.32, 0.3)

var zombie_id: String = ""
var lane: int = 0
var max_hp: int = 200
var hp: int = 200
var base_speed: float = 26.0
var has_hat := false
var hat_max_hp := 0
var hat_hp := 0
var state: E_State = E_State.Walk
var is_fast_death := false

var game: MainGameManager = null
var sprite: AnimatedSprite2D = null
var target_plant: PlantBase = null

var _data: Dictionary = {}
var _draw_size := Vector2.ZERO
var _anim_name := ""
var _bite_timer := 0.0
var _slow_timer := 0.0
var _death_timer := 0.0


func setup(zombie_id_value: String, lane_value: int, spawn_x: float,
		game_ref: MainGameManager) -> void:
	zombie_id = zombie_id_value
	lane = lane_value
	game = game_ref
	_data = GameConfig.zombie_data(zombie_id)
	max_hp = int(_data.get("hp", 200))
	hp = max_hp
	base_speed = float(_data.get("speed", 26.0))
	hat_max_hp = int(_data.get("hat_hp", 0))
	hat_hp = hat_max_hp
	has_hat = hat_max_hp > 0
	_draw_size = Vector2(float(_data.get("zw", 128.0)), float(_data.get("zh", 150.0)))
	position = Vector2(spawn_x, GameConfig.cell_center_y(lane))


func _ready() -> void:
	z_index = lane
	sprite = SpriteLibrary.make_sprite(_anim_sheets(), _draw_size.x, _draw_size.y, ["burnt"])
	add_child(sprite)
	if bool(_data.get("has_flag", false)):
		var flag := SpriteLibrary.make_static_sprite("flag",
				GameConfig.FX_FLAG_W, GameConfig.FX_FLAG_H)
		flag.position = Vector2(58.0, -34.0)
		add_child(flag)
	_sync_anim()


func _anim_sheets() -> Dictionary:
	var sheets := {
		"walk": String(_data.get("walk", "z_basic_walk")),
		"attack": String(_data.get("attack", "z_basic_attack")),
		"dirty_walk": String(_data.get("dirty_walk", "z_losthead_walk")),
		"dirty_attack": String(_data.get("dirty_attack", "z_losthead_attack")),
		"burnt": "z_burnt",
	}
	if _data.has("hat_removed_walk"):
		sheets["bare_walk"] = String(_data["hat_removed_walk"])
		sheets["bare_attack"] = String(_data["hat_removed_attack"])
	return sheets


func _process(delta: float) -> void:
	if game == null:
		return
	match state:
		E_State.Walk:
			if game.is_running():
				_tick_walk(delta)
		E_State.Eat:
			if game.is_running():
				_tick_eat(delta)
		E_State.Dying:
			_tick_dying(delta)
		E_State.Burnt:
			pass


# ---------------- 状态推进 ----------------
func _tick_walk(delta: float) -> void:
	_update_slow(delta)
	position.x -= current_speed() * delta
	var bite_x := position.x - BITE_OFFSET
	var plant := game.grid_manager.find_eatable_plant(lane, bite_x)
	if plant != null:
		target_plant = plant
		state = E_State.Eat
		_bite_timer = 0.0
		_sync_anim()
		return
	_check_breach()


func _tick_eat(delta: float) -> void:
	_update_slow(delta)
	if target_plant == null or not is_instance_valid(target_plant) or target_plant.is_dead:
		_stop_eating()
		return
	var bite_x := position.x - BITE_OFFSET
	if game.grid_manager.find_eatable_plant(lane, bite_x) != target_plant:
		_stop_eating()
		return
	_bite_timer -= delta
	if _bite_timer > 0.0:
		return
	_bite_timer = GameConfig.ZOMBIE_BITE_INTERVAL
	target_plant.take_damage(GameConfig.ZOMBIE_BITE_DAMAGE)
	game.play_sfx("chomp")


func _stop_eating() -> void:
	target_plant = null
	state = E_State.Walk
	_sync_anim()


func _tick_dying(delta: float) -> void:
	_death_timer += delta
	var duration := GameConfig.ZOMBIE_FAST_DEATH_TIME if is_fast_death \
			else GameConfig.ZOMBIE_DEATH_TIME
	modulate.a = clampf(1.0 - _death_timer / duration, 0.0, 1.0)
	if _death_timer >= duration:
		queue_free()


func _update_slow(delta: float) -> void:
	if _slow_timer <= 0.0:
		return
	_slow_timer -= delta
	if _slow_timer <= 0.0:
		_slow_timer = 0.0
		_sync_anim()


func _check_breach() -> void:
	if position.x <= GameConfig.MOWER_TRIGGER_X:
		game.mower_manager.trigger_lane(lane)
	if position.x <= GameConfig.LOSE_X:
		game.on_zombie_breached(self)


# ---------------- 受击 ----------------
func can_be_hit() -> bool:
	return state == E_State.Walk or state == E_State.Eat


func current_speed() -> float:
	var speed := base_speed
	if not has_hat and _data.has("hat_removed_speed"):
		speed = float(_data["hat_removed_speed"])
	if _slow_timer > 0.0:
		speed *= GameConfig.SLOW_FACTOR
	return speed


func hp_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)


## 常规伤害：先消耗顶具护甲，再扣本体生命
func take_damage(amount: int) -> void:
	if not can_be_hit() or amount <= 0:
		return
	var remaining := amount
	if has_hat:
		var absorbed := mini(hat_hp, remaining)
		hat_hp -= absorbed
		remaining -= absorbed
		if hat_hp <= 0:
			has_hat = false
	if remaining > 0:
		hp -= remaining
	_sync_anim()
	if hp <= 0:
		kill(false)


## 直接致死：吞噬 / 碾压（无视顶具）
func kill_directly() -> void:
	if not can_be_hit():
		return
	hp = 0
	kill(true)


func apply_slow() -> void:
	if not can_be_hit():
		return
	_slow_timer = GameConfig.SLOW_DURATION
	_sync_anim()


func kill(fast: bool) -> void:
	if not can_be_hit():
		return
	state = E_State.Dying
	is_fast_death = fast
	_death_timer = 0.0
	EventBus.zombie_died.emit(lane, false)
	game.on_zombie_killed()


## 被火烧焦：播放焦尸动画后销毁
func burn() -> void:
	if state == E_State.Burnt or state == E_State.Dying:
		return
	state = E_State.Burnt
	hp = 0
	target_plant = null
	if sprite != null:
		sprite.play("burnt")
		sprite.modulate = BURNT_TINT
		sprite.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)
	EventBus.zombie_died.emit(lane, true)
	game.on_zombie_killed()


# ---------------- 外观 ----------------
func _sync_anim() -> void:
	if sprite == null:
		return
	var anim := _current_anim()
	if anim != _anim_name:
		_anim_name = anim
		sprite.play(StringName(anim))
	var target_scale := GameConfig.SLOW_FACTOR if _slow_timer > 0.0 else 1.0
	if not is_equal_approx(sprite.speed_scale, target_scale):
		sprite.speed_scale = target_scale
	sprite.modulate = FROZEN_TINT if _slow_timer > 0.0 else Color.WHITE


func _current_anim() -> String:
	var eating := state == E_State.Eat
	if hp_ratio() < float(_data.get("dirt_ratio", 0.0)):
		return "dirty_attack" if eating else "dirty_walk"
	if not has_hat and _data.has("hat_removed_walk"):
		return "bare_attack" if eating else "bare_walk"
	return "attack" if eating else "walk"


# ---------------- 单局快照 ----------------
## 单局快照：仅 Walk / Eat 状态入档（Dying / Burnt 属瞬态，由调用方过滤）
func to_snapshot() -> Dictionary:
	return {
		"type": zombie_id, "row": lane, "x": position.x, "hp": hp,
		"has_hat": has_hat, "hat_hp": hat_hp,
		"state": int(state), "slow_t": _slow_timer, "bite_t": _bite_timer,
	}


## 读档恢复：位置 / 生命 / 顶具 / 状态机（仅还原 Walk / Eat，目标植物由 AI 重新捕获）
func apply_snapshot(data: Dictionary) -> void:
	position.x = float(data.get("x", position.x))
	hp = int(data.get("hp", hp))
	has_hat = bool(data.get("has_hat", has_hat))
	hat_hp = int(data.get("hat_hp", hat_hp))
	_slow_timer = maxf(0.0, float(data.get("slow_t", 0.0)))
	_bite_timer = maxf(0.0, float(data.get("bite_t", 0.0)))
	state = _state_from_int(int(data.get("state", E_State.Walk)))
	target_plant = null
	if sprite != null:
		_anim_name = ""
		_sync_anim()


## 整数还原枚举（Dying / Burnt 不入档，非法值一律回退 Walk）
func _state_from_int(value: int) -> E_State:
	match value:
		1:
			return E_State.Eat
		_:
			return E_State.Walk