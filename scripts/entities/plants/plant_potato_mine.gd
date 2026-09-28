class_name PlantPotatoMine
extends PlantBase
## 土豆地雷：埋地 15 秒后武装，僵尸靠近即引爆

const BLAST_RADIUS := 90.0

var _armed := false
var _arm_timer := 0.0


func _anim_sheets() -> Dictionary:
	return {"buried": "potato_buried", "armed": "potato_armed"}


func _on_planted() -> void:
	_arm_timer = float(GameConfig.PLANT_BEHAVIOR["potato_mine"]["arm_time"])
	if sprite != null:
		sprite.play("buried")


func _tick(delta: float) -> void:
	if not _armed:
		_arm_timer -= delta
		if _arm_timer > 0.0:
			return
		_armed = true
		if sprite != null:
			sprite.play("armed")
		return

	var trigger := float(GameConfig.PLANT_BEHAVIOR["potato_mine"]["trigger_x"])
	for zombie in lane_zombies():
		if not zombie.can_be_hit():
			continue
		if absf(zombie.position.x - position.x) <= trigger:
			_explode(zombie)
			return


func _explode(zombie: ZombieBase) -> void:
	var damage := int(GameConfig.PLANT_BEHAVIOR["potato_mine"]["damage"])
	game.damage_zombies_near(Vector2(zombie.position.x, position.y), BLAST_RADIUS, damage)
	game.spawn_fx("explosion", zombie.position - Vector2(0.0, 40.0),
			GameConfig.FX_EXPLOSION_D * 0.65)
	play_sfx("cherrybomb")
	vanish()