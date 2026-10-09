class_name ZombieNewspaper
extends ZombieBase
## 读报僵尸：报纸是被撕掉的独立护甲段
## 报纸被摧毁瞬间播放「撕报纸」一次性动画并僵直，动画播完后换无报纸外观并提速继续前进

var _ripping := false


func _anim_sheets() -> Dictionary:
	var sheets := super._anim_sheets()
	sheets["rip"] = String(_data.get("rip", "z_newspaper_rip"))
	return sheets


func _once_anims() -> Array:
	return ["burnt", "rip"]


func _process(delta: float) -> void:
	if _ripping and can_be_hit():
		if game == null or not game.is_running():
			return
		_update_slow(delta)
		return
	_ripping = false
	super._process(delta)


func take_damage(amount: int) -> void:
	var had_hat := has_hat
	super.take_damage(amount)
	if had_hat and not has_hat and can_be_hit():
		_start_rip()


func _current_anim() -> String:
	if _ripping:
		return "rip"
	return super._current_anim()


## 进入僵直：中断啃食，播放撕裂动画，动画播完自动恢复
func _start_rip() -> void:
	if sprite == null:
		return
	_ripping = true
	target_plant = null
	state = E_State.Walk
	_sync_anim()
	sprite.animation_finished.connect(_on_rip_finished, CONNECT_ONE_SHOT)


func _on_rip_finished() -> void:
	if not _ripping:
		return
	_ripping = false
	_sync_anim()


# ---------------- 单局快照 ----------------
## 撕裂是瞬态过渡，不入档：读档后直接按「报纸是否还在」恢复常规状态
func apply_snapshot(data: Dictionary) -> void:
	_ripping = false
	super.apply_snapshot(data)
