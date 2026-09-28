class_name PlantBomb
extends PlantBase
## 一次性炸弹：樱桃炸弹（3×3 范围爆炸）/ 火爆辣椒（清空整行并烧焦）

var _fuse := 0.0


func _once_anims() -> Array:
	return ["main"]


func _on_planted() -> void:
	_fuse = float(GameConfig.PLANT_BEHAVIOR[plant_id]["fuse"])
	play_sfx("cherrybomb" if plant_id == "cherrybomb" else "jalapeno")


func _tick(delta: float) -> void:
	_fuse -= delta
	if _fuse > 0.0:
		return
	_explode()


func _explode() -> void:
	var damage := int(GameConfig.PLANT_BEHAVIOR[plant_id]["damage"])
	if plant_id == "cherrybomb":
		game.explode_area(cell, 1, damage)
		game.spawn_fx("explosion", GameConfig.cell_center(cell), GameConfig.FX_EXPLOSION_D)
	else:
		game.burn_lane(cell.y, damage)
		game.spawn_fx("fire", GameConfig.cell_center(cell), GameConfig.FX_FIRE_D)
	vanish()