class_name SpriteMeta
extends RefCounted
## 自动生成，请勿手改：精灵表帧元数据（横向精灵表，帧宽高一致）
## 生成命令：python tools/gen_sprite_meta.py ../pvzcode/js/sprites-meta.js

const SHEETS := {
	"sunflower": {"w": 73, "h": 74, "frames": 18, "d": 0.11, "src": "res://assets/sprites/sunflower.png"},
	"peashooter": {"w": 71, "h": 71, "frames": 13, "d": 0.09, "src": "res://assets/sprites/peashooter.png"},
	"repeater": {"w": 73, "h": 71, "frames": 15, "d": 0.09, "src": "res://assets/sprites/repeater.png"},
	"snowpea": {"w": 71, "h": 71, "frames": 15, "d": 0.09, "src": "res://assets/sprites/snowpea.png"},
	"threepeater": {"w": 73, "h": 80, "frames": 16, "d": 0.09, "src": "res://assets/sprites/threepeater.png"},
	"walnut_full": {"w": 66, "h": 75, "frames": 4, "d": 0.2, "src": "res://assets/sprites/walnut_full.png"},
	"walnut_half": {"w": 66, "h": 75, "frames": 4, "d": 0.2, "src": "res://assets/sprites/walnut_half.png"},
	"walnut_low": {"w": 66, "h": 75, "frames": 4, "delays": [0.2, 0.2, 0.2, 1.0], "src": "res://assets/sprites/walnut_low.png"},
	"cherry": {"w": 112, "h": 81, "frames": 7, "d": 0.09, "src": "res://assets/sprites/cherry.png"},
	"jalapeno": {"w": 68, "h": 89, "frames": 8, "d": 0.09, "src": "res://assets/sprites/jalapeno.png"},
	"squash_idle": {"w": 100, "h": 226, "frames": 17, "d": 0.09, "src": "res://assets/sprites/squash_idle.png"},
	"squash_attack": {"w": 100, "h": 226, "frames": 4, "delays": [0.36, 0.09, 0.27, 0.9], "src": "res://assets/sprites/squash_attack.png"},
	"chomper_idle": {"w": 130, "h": 114, "frames": 13, "delays": [0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.09], "src": "res://assets/sprites/chomper_idle.png"},
	"chomper_attack": {"w": 130, "h": 114, "frames": 6, "delays": [0.18, 0.18, 0.18, 0.18, 0.18, 0.09], "src": "res://assets/sprites/chomper_attack.png"},
	"potato_buried": {"w": 75, "h": 55, "frames": 1, "d": 0.1, "src": "res://assets/sprites/potato_buried.png"},
	"potato_armed": {"w": 75, "h": 55, "frames": 8, "d": 0.2, "src": "res://assets/sprites/potato_armed.png"},
	"explosion": {"w": 100, "h": 100, "frames": 31, "d": 0.1, "src": "res://assets/sprites/explosion.png"},
	"fire": {"w": 100, "h": 100, "frames": 18, "d": 0.1, "src": "res://assets/sprites/fire.png"},
	"mower_idle": {"w": 100, "h": 100, "frames": 1, "d": 0.1, "src": "res://assets/sprites/mower_idle.png"},
	"mower_on": {"w": 100, "h": 100, "frames": 13, "d": 0.1, "src": "res://assets/sprites/mower_on.png"},
	"z_burnt": {"w": 100, "h": 200, "frames": 30, "delays": [0.4, 0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.4, 0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.32, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.16, 0.16, 0.16], "src": "res://assets/sprites/z_burnt.png"},
	"z_basic_walk": {"w": 166, "h": 144, "frames": 18, "delays": [0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.1], "src": "res://assets/sprites/z_basic_walk.png"},
	"z_basic_attack": {"w": 166, "h": 144, "frames": 21, "delays": [0.15, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1], "src": "res://assets/sprites/z_basic_attack.png"},
	"z_cone_walk": {"w": 166, "h": 144, "frames": 21, "delays": [0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.09], "src": "res://assets/sprites/z_cone_walk.png"},
	"z_cone_attack": {"w": 166, "h": 144, "frames": 11, "d": 0.09, "src": "res://assets/sprites/z_cone_attack.png"},
	"z_bucket_walk": {"w": 166, "h": 144, "frames": 15, "d": 0.18, "src": "res://assets/sprites/z_bucket_walk.png"},
	"z_bucket_attack": {"w": 166, "h": 144, "frames": 11, "d": 0.09, "src": "res://assets/sprites/z_bucket_attack.png"},
	"z_football_walk": {"w": 154, "h": 160, "frames": 11, "d": 0.09, "src": "res://assets/sprites/z_football_walk.png"},
	"z_football_attack": {"w": 154, "h": 160, "frames": 10, "d": 0.09, "src": "res://assets/sprites/z_football_attack.png"},
	"z_door_walk": {"w": 166, "h": 144, "frames": 23, "delays": [0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.09], "src": "res://assets/sprites/z_door_walk.png"},
	"z_door_attack": {"w": 166, "h": 157, "frames": 12, "d": 0.09, "src": "res://assets/sprites/z_door_attack.png"},
	"z_losthead_walk": {"w": 166, "h": 144, "frames": 18, "d": 0.07, "src": "res://assets/sprites/z_losthead_walk.png"},
	"z_losthead_attack": {"w": 166, "h": 144, "frames": 11, "d": 0.07, "src": "res://assets/sprites/z_losthead_attack.png"},
}


## 取某张精灵表的逐帧时长（秒）
static func delays(sheet: String) -> Array[float]:
	var out: Array[float] = []
	var meta: Dictionary = SHEETS.get(sheet, {})
	if meta.is_empty():
		return out
	if meta.has("delays"):
		for value in meta["delays"]:
			out.append(float(value))
		return out
	var uniform := float(meta["d"])
	for i in int(meta["frames"]):
		out.append(uniform)
	return out


## 取某张精灵表的单帧尺寸
static func frame_size(sheet: String) -> Vector2:
	var meta: Dictionary = SHEETS.get(sheet, {})
	if meta.is_empty():
		return Vector2.ONE
	return Vector2(float(meta["w"]), float(meta["h"]))
