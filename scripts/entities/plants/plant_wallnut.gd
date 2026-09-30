class_name PlantWallnut
extends PlantBase
## 坚果墙：高血量阻挡物，按剩余生命切换 完整 / 半损 / 濒破 外观

const RATIO_HALF := 0.66
const RATIO_LOW := 0.33

var _anim_name := ""


func _anim_sheets() -> Dictionary:
	return {
		"full": "walnut_full",
		"half": "walnut_half",
		"low": "walnut_low",
	}


func _on_planted() -> void:
	_refresh_anim()


## 单局快照：外观由剩余生命推导，无需存私有字段；读档时按恢复后的 hp 重绘外观
func restore_state(_data: Dictionary) -> void:
	_anim_name = ""
	_refresh_anim()


func _tick(_delta: float) -> void:
	_refresh_anim()


func _refresh_anim() -> void:
	var ratio := hp_ratio()
	var target := "full"
	if ratio <= RATIO_LOW:
		target = "low"
	elif ratio <= RATIO_HALF:
		target = "half"
	if target == _anim_name or sprite == null:
		return
	_anim_name = target
	sprite.play(StringName(target))