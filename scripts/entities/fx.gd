class_name Fx
extends Node2D
## 一次性特效：爆炸 / 火焰等，播放完自动销毁

const Z_LAYER := 0

var _sheet := ""
var _draw_size := 0.0
var _speed_scale := 1.0


## 在 parent 下生成一个只播放一次的特效
static func spawn(parent: Node, sheet: String, pos: Vector2, draw_size: float,
		speed_scale := 1.0) -> void:
	if parent == null:
		return
	var fx := Fx.new()
	fx._sheet = sheet
	fx._draw_size = draw_size
	fx._speed_scale = speed_scale
	fx.position = pos
	parent.add_child(fx)


func _ready() -> void:
	var sprite := SpriteLibrary.make_sprite({"main": _sheet}, _draw_size, _draw_size, ["main"])
	sprite.speed_scale = _speed_scale
	add_child(sprite)
	sprite.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)