class_name PlantSunflower
extends PlantBase
## 向日葵：定时产出阳光（首个 12s，之后每 12s）

var _timer := 0.0


func _on_planted() -> void:
	_timer = float(GameConfig.PLANT_BEHAVIOR["sunflower"]["first_sun"])


## 单局快照：产阳光计时器
func snapshot_state() -> Dictionary:
	return {"t": _timer}


func restore_state(data: Dictionary) -> void:
	_timer = float(data.get("t", _timer))


func _tick(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = float(GameConfig.PLANT_BEHAVIOR["sunflower"]["sun_interval"])
	game.spawn_sun(position + Vector2(0.0, -6.0), GameConfig.SUNFLOWER_SUN_VALUE, "plant")