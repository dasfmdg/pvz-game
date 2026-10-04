class_name MelonBullet
extends Node2D
## 西瓜弹体：直线飞行 + 命中直伤 + 相邻行溅射（溅射范围对齐参考实现 js/game.js applySplash）
## 飞行途中叠加正弦起伏，仅作投掷观感，不参与命中判定

## 命中判定半宽（与豌豆一致）与出界回收阈值
const HIT_HALF_WIDTH := 44.0
const OFFSCREEN_X := 2100.0
## 溅射覆盖的相邻行数，以及横向范围相对格子宽度的比例
const SPLASH_ROW_SPAN := 1
const SPLASH_X_RATIO := 0.9
## 视觉弧线完成一次起伏的像素跨度
const ARC_WAVELENGTH := 320.0
## 命中音效（复用现有音效池，不新增音频素材）
const HIT_SOUND := "splat3"

var lane := 0
var damage := 80
var splash_damage := 40
var slows := true

var game: MainGameManager = null
var sprite: Sprite2D = null

var _start_x := 0.0
var _base_y := 0.0


func setup(lane_value: int, start_pos: Vector2, damage_value: int, splash_value: int,
		apply_slow: bool, game_ref: MainGameManager) -> void:
	lane = lane_value
	damage = damage_value
	splash_damage = splash_value
	slows = apply_slow
	game = game_ref
	position = start_pos
	_start_x = start_pos.x
	_base_y = start_pos.y


func _ready() -> void:
	z_index = lane
	sprite = SpriteLibrary.make_static_sprite("melon",
			GameConfig.MELON_DRAW_W, GameConfig.MELON_DRAW_H)
	add_child(sprite)


func _process(delta: float) -> void:
	if game == null or not game.is_running():
		return
	position.x += GameConfig.MELON_SPEED * delta
	_apply_arc()
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


## 纵向上按飞行距离做正弦起伏：起手抬起、落地回位
func _apply_arc() -> void:
	var travelled := position.x - _start_x
	position.y = _base_y - sin(travelled / ARC_WAVELENGTH * PI) * GameConfig.MELON_ARC_HEIGHT


func _hit(zombie: ZombieBase) -> void:
	zombie.take_damage(damage)
	if slows:
		zombie.apply_slow()
	_splash(zombie)
	game.play_sfx(HIT_SOUND)
	queue_free()


## 溅射：命中点上下各一行、横向范围内的僵尸承受溅射伤害，直击目标不重复结算
func _splash(hit: ZombieBase) -> void:
	var hit_x := hit.position.x
	var x_range := GameConfig.CELL_W * SPLASH_X_RATIO
	for row in range(lane - SPLASH_ROW_SPAN, lane + SPLASH_ROW_SPAN + 1):
		if row < 0 or row >= GameConfig.ROWS:
			continue
		for zombie in game.zombies_in_lane(row):
			if zombie == hit or not zombie.can_be_hit():
				continue
			if absf(zombie.position.x - hit_x) > x_range:
				continue
			zombie.take_damage(splash_damage)
			if slows:
				zombie.apply_slow()