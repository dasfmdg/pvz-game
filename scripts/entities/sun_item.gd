class_name SunItem
extends Node2D
## 阳光：天降阳光从空中落到随机高度；植物产出的阳光就地弹出
## 点击收集（由 MainGameManager 统一路由），超时自动消失

const COLLECT_RADIUS := 56.0
const FALL_SPEED := 190.0
const POP_TIME := 0.45
const BLINK_TIME := 2.5

enum E_Kind { Sky, Plant }

var value := 50
var kind: E_Kind = E_Kind.Sky

var game: MainGameManager = null
var sprite: Sprite2D = null

var _landed := false
var _life := 0.0
var _bob := 0.0
var _target_y := 0.0
var _is_collected := false


func setup(value_value: int, kind_value: E_Kind, target_y: float,
		game_ref: MainGameManager) -> void:
	value = value_value
	kind = kind_value
	_target_y = target_y
	game = game_ref


func _ready() -> void:
	z_index = 0
	sprite = SpriteLibrary.make_static_sprite("sun", GameConfig.FX_SUN_D, GameConfig.FX_SUN_D)
	add_child(sprite)
	_target_y = minf(_target_y, GameConfig.CANVAS_H - 60.0)


func _process(delta: float) -> void:
	if _is_collected:
		return
	if game != null and not game.is_running():
		return
	if not _landed:
		_advance_falling(delta)
		return
	_bob += delta * 3.0
	sprite.position.y = sin(_bob) * 4.0
	_life -= delta
	if _life <= BLINK_TIME:
		modulate.a = 0.45 + 0.55 * absf(sin(_life * 6.0))
	if _life <= 0.0:
		queue_free()


func _advance_falling(delta: float) -> void:
	match kind:
		E_Kind.Sky:
			position.y += FALL_SPEED * delta
			if position.y >= _target_y:
				position.y = _target_y
				_land()
		E_Kind.Plant:
			var step := (position.y - (_target_y - 40.0)) * minf(1.0, delta / POP_TIME)
			position.y -= step
			if absf(position.y - (_target_y - 40.0)) < 2.0:
				_land()


func _land() -> void:
	_landed = true
	_life = GameConfig.SUN_LIFETIME


func collect() -> void:
	if _is_collected:
		return
	_is_collected = true
	if game != null:
		game.add_sun(value)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.45, 1.45), 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)