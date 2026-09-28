class_name PeaBullet
extends Node2D
## 豌豆 / 冰豌豆：直线飞行，命中同路第一个僵尸

const HIT_HALF_WIDTH := 44.0
const OFFSCREEN_X := 2100.0
const FROZEN_TINT := Color(0.62, 0.86, 1.0)

var lane := 0
var damage := 20
var speed := 430.0
var is_ice := false

var game: MainGameManager = null
var sprite: Sprite2D = null


func setup(lane_value: int, start_pos: Vector2, damage_value: int, ice: bool,
		game_ref: MainGameManager) -> void:
	lane = lane_value
	damage = damage_value
	is_ice = ice
	game = game_ref
	speed = GameConfig.ICE_PEA_SPEED if ice else GameConfig.PEA_SPEED
	position = start_pos


func _ready() -> void:
	z_index = lane
	var draw_size := GameConfig.ICE_PEA_DRAW if is_ice else GameConfig.PEA_DRAW
	sprite = SpriteLibrary.make_static_sprite("pea", draw_size, draw_size)
	if is_ice:
		sprite.modulate = FROZEN_TINT
	add_child(sprite)


func _process(delta: float) -> void:
	if game == null or not game.is_running():
		return
	position.x += speed * delta
	if position.x > OFFSCREEN_X:
		queue_free()
		return
	for zombie in game.zombies_in_lane(lane):
		if not zombie.can_be_hit():
			continue
		if absf(zombie.position.x - position.x) > HIT_HALF_WIDTH:
			continue
		_hit(zombie)
		return


func _hit(zombie: ZombieBase) -> void:
	zombie.take_damage(damage)
	if is_ice:
		zombie.apply_slow()
	game.play_sfx("splat3")
	queue_free()