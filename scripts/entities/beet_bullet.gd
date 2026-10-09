class_name BeetBullet
extends Node2D
## 甜菜弹：沿本行直线飞行，命中僵尸后不消失，可依次穿透整行
## 同一僵尸只会被同一发结算一次（按实例 id 去重）

const OFFSCREEN_X := 2100.0

var lane := 0
var damage := 45

var game: MainGameManager = null
var sprite: Sprite2D = null

var _hit_ids: Dictionary = {}


func setup(lane_value: int, start_pos: Vector2, damage_value: int,
		game_ref: MainGameManager) -> void:
	lane = lane_value
	damage = damage_value
	game = game_ref
	position = start_pos


func _ready() -> void:
	z_index = lane
	sprite = SpriteLibrary.make_static_sprite("beetbullet",
			GameConfig.BEET_DRAW_W, GameConfig.BEET_DRAW_H)
	add_child(sprite)


func _process(delta: float) -> void:
	if game == null or not game.is_running():
		return
	position.x += GameConfig.BEET_SPEED * delta
	if position.x > OFFSCREEN_X:
		queue_free()
		return
	for zombie in game.zombies_in_lane(lane):
		if not zombie.can_be_hit():
			continue
		var zombie_key := zombie.get_instance_id()
		if _hit_ids.has(zombie_key):
			continue
		if absf(zombie.position.x - position.x) > GameConfig.BEET_HIT_HALF_WIDTH:
			continue
		_hit_ids[zombie_key] = true
		zombie.take_damage(damage)
		game.play_sfx("splat3")
