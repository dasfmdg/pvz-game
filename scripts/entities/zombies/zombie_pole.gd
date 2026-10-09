class_name ZombiePole
extends ZombieBase
## 撑杆僵尸：行进途中遇到第一株植物时原地起跳翻越一格，落地后换用「跳后行走」外观
## 翻越距离与时长由 GameConfig.POLE_VAULT_* 配置，仅能翻越一次
## 跳跃动画在素材构建阶段已去掉烘焙的横向位移，位移完全由本类的 _tick_jump 驱动

var _vaulted := false
var _jumping := false
var _jump_timer := 0.0
var _jump_from_x := 0.0


func _anim_sheets() -> Dictionary:
	var sheets := super._anim_sheets()
	sheets["after_jump_walk"] = String(_data.get("after_jump_walk", "z_pole_after_jump"))
	sheets["jump"] = String(_data.get("jump", "z_pole_jump"))
	return sheets


func _process(delta: float) -> void:
	if _jumping and can_be_hit():
		if game == null or not game.is_running():
			return
		_tick_jump(delta)
		return
	_jumping = false
	super._process(delta)


# ---------------- 翻越 ----------------
func _tick_walk(delta: float) -> void:
	if _try_vault():
		return
	super._tick_walk(delta)


## 嘴部前方 POLE_VAULT_TRIGGER_X 处出现可啃植物即起跳（一生仅一次）
func _try_vault() -> bool:
	if _vaulted or game == null:
		return false
	var probe_x := position.x - BITE_OFFSET - GameConfig.POLE_VAULT_TRIGGER_X
	if game.grid_manager.find_eatable_plant(lane, probe_x) == null:
		return false
	_vaulted = true
	_jumping = true
	_jump_timer = 0.0
	_jump_from_x = position.x
	target_plant = null
	state = E_State.Walk
	_sync_anim()
	return true


func _tick_jump(delta: float) -> void:
	_update_slow(delta)
	_jump_timer += delta
	var ratio := clampf(_jump_timer / GameConfig.POLE_VAULT_TIME, 0.0, 1.0)
	position.x = _jump_from_x - GameConfig.POLE_VAULT_DISTANCE * ratio
	if ratio < 1.0:
		return
	_jumping = false
	target_plant = null
	state = E_State.Walk
	_sync_anim()


func _current_anim() -> String:
	if _jumping:
		return "jump"
	if hp_ratio() < float(_data.get("dirt_ratio", 0.0)):
		return super._current_anim()
	if _vaulted and state != E_State.Eat:
		return "after_jump_walk"
	return super._current_anim()


# ---------------- 单局快照 ----------------
func to_snapshot() -> Dictionary:
	var data := super.to_snapshot()
	data["vaulted"] = _vaulted
	return data


func apply_snapshot(data: Dictionary) -> void:
	_vaulted = bool(data.get("vaulted", _vaulted))
	_jumping = false
	super.apply_snapshot(data)
