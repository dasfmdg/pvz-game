class_name LawnMower
extends Node2D
## 小推车：僵尸抵达触发线时启动，沿途碾压本行僵尸，冲出屏幕后销毁
## 每行仅能触发一次（used 标记），触发后该行失去保护

const KILL_HALF_WIDTH := 70.0

var lane := 0
var used := false
var running := false

var game: MainGameManager = null
var sprite: AnimatedSprite2D = null


func setup(lane_value: int, game_ref: MainGameManager) -> void:
	lane = lane_value
	game = game_ref
	position = Vector2(GameConfig.MOWER_X, GameConfig.cell_center_y(lane))


func _ready() -> void:
	z_index = lane
	sprite = SpriteLibrary.make_sprite(
		{"idle": "mower_idle", "on": "mower_on"},
		GameConfig.MOWER_DRAW, GameConfig.MOWER_DRAW, [], "idle")
	add_child(sprite)


func trigger() -> void:
	if used:
		return
	used = true
	running = true
	if sprite != null:
		sprite.play("on")
	SoundManager.play("lawnmower")


func _process(delta: float) -> void:
	if not running or game == null or not game.is_running():
		return
	position.x += GameConfig.MOWER_SPEED * delta
	for zombie in game.zombies_in_lane(lane):
		if not zombie.can_be_hit():
			continue
		if absf(zombie.position.x - position.x) <= KILL_HALF_WIDTH:
			zombie.kill_directly()
	if position.x > GameConfig.CANVAS_W + 150.0:
		queue_free()


# ---------------- 单局快照 ----------------
## 单局快照：所在行 / 是否已用 / 是否冲出中 / 当前横坐标（冲出中的按当前位置继续跑）
func to_snapshot() -> Dictionary:
	return {"row": lane, "used": used, "running": running, "x": position.x}


## 读档恢复：还原位置与状态，冲出中的继续播放启动动画
func apply_snapshot(data: Dictionary) -> void:
	position.x = float(data.get("x", position.x))
	used = bool(data.get("used", used))
	running = bool(data.get("running", running))
	if sprite != null:
		sprite.play("on" if running else "idle")