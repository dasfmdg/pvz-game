extends Node
## 全局数值配置：棋盘 / 经济 / 植物 / 僵尸 / 波次 / 小推车 / 弹道
## 数值对齐参考实现 js/config.js 与原作，业务代码中禁止硬编码数值。

# ---------------- 棋盘（坐标系基于 1920×1080 草坪背景） ----------------
const ROWS := 5
const COLS := 9
const GRID_X := 606.0
const GRID_Y := 178.0
const CELL_W := 145.0
const CELL_H := 169.0
const CANVAS_W := 1920.0
const CANVAS_H := 1080.0

## 纵向位置微调：草坪条纹 y 176..1029，实体统一上移该偏移量落在行中央
const POS_OFFSET_Y := 24.0

# ---------------- 经济 ----------------
const START_SUN := 50
const SKY_SUN_INTERVAL := 10.0
const SKY_SUN_FIRST := 10.0
const SKY_SUN_VALUE := 50
const SUNFLOWER_SUN_VALUE := 50
const SUN_LIFETIME := 12.0

# ---------------- 植物 ----------------
## cost 价格 / hp 生命 / recharge 卡片冷却(秒) / sheet 精灵表
## dw,dh 棋盘绘制尺寸 / name 显示名
const PLANTS := {
	"sunflower": {
		"name": "Sunflower", "cost": 50, "hp": 300, "recharge": 5.0,
		"sheet": "sunflower", "dw": 118.0, "dh": 117.0,
	},
	"peashooter": {
		"name": "Peashooter", "cost": 100, "hp": 300, "recharge": 6.0,
		"sheet": "peashooter", "dw": 112.0, "dh": 115.0,
	},
	"wallnut": {
		"name": "Wall-nut", "cost": 50, "hp": 4000, "recharge": 7.0,
		"sheet": "walnut_full", "dw": 120.0, "dh": 136.0,
	},
	"cherrybomb": {
		"name": "Cherry Bomb", "cost": 150, "hp": 300, "recharge": 15.0,
		"sheet": "cherry", "dw": 120.0, "dh": 96.0,
	},
	"repeater": {
		"name": "Repeater", "cost": 200, "hp": 300, "recharge": 10.0,
		"sheet": "repeater", "dw": 112.0, "dh": 115.0,
	},
	"jalapeno": {
		"name": "Jalapeno", "cost": 125, "hp": 300, "recharge": 12.0,
		"sheet": "jalapeno", "dw": 140.0, "dh": 140.0,
	},
	"snowpea": {
		"name": "Snow Pea", "cost": 175, "hp": 300, "recharge": 7.5,
		"sheet": "snowpea", "dw": 112.0, "dh": 115.0,
	},
	"threepeater": {
		"name": "Threepeater", "cost": 325, "hp": 300, "recharge": 7.5,
		"sheet": "threepeater", "dw": 112.0, "dh": 115.0,
	},
	"potato_mine": {
		"name": "Potato Mine", "cost": 25, "hp": 300, "recharge": 20.0,
		"sheet": "potato_buried", "dw": 90.0, "dh": 66.0,
	},
	"squash": {
		"name": "Squash", "cost": 50, "hp": 300, "recharge": 12.0,
		"sheet": "squash_idle", "dw": 150.0, "dh": 339.0,
	},
	"chomper": {
		"name": "Chomper", "cost": 150, "hp": 300, "recharge": 11.0,
		"sheet": "chomper_idle", "dw": 96.0, "dh": 112.0,
	},
}

## 卡槽顺序
const PLANT_ORDER: Array[String] = [
	"sunflower", "peashooter", "wallnut", "cherrybomb", "repeater", "jalapeno",
	"snowpea", "threepeater", "squash", "chomper", "potato_mine",
]

## 植物行为参数
const PLANT_BEHAVIOR := {
	"sunflower": {"first_sun": 12.0, "sun_interval": 12.0},
	"peashooter": {"fire_interval": 1.5, "first_fire": 0.6, "damage": 20},
	"repeater": {"fire_interval": 1.5, "first_fire": 0.6, "damage": 20, "second_delay": 0.13},
	"snowpea": {"fire_interval": 1.4, "first_fire": 0.6, "damage": 20},
	"threepeater": {"fire_interval": 1.5, "first_fire": 0.6, "damage": 20},
	"potato_mine": {"arm_time": 15.0, "damage": 1800, "trigger_x": 60.0},
	"squash": {"trigger_x": 130.0, "damage": 1800, "squash_time": 0.55},
	"chomper": {"trigger_x": 60.0, "damage": 1800, "rest_time": 15.0},
	"cherrybomb": {"fuse": 1.15, "damage": 1800},
	"jalapeno": {"fuse": 1.15, "damage": 1800},
}

# ---------------- 僵尸 ----------------
## hp 总生命 / speed px每秒 / zw,zh 绘制尺寸
## hat 顶具独立生命段（打爆后换无顶具外观，可选减速）
## dirties 破损外观 + dirt_ratio：剩余生命比例低于该值时切破损态
const ZOMBIES := {
	"basic": {
		"name": "Zombie", "hp": 200, "speed": 26.0, "zw": 128.0, "zh": 150.0,
		"walk": "z_basic_walk", "attack": "z_basic_attack",
		"dirty_walk": "z_losthead_walk", "dirty_attack": "z_losthead_attack",
		"dirt_ratio": 0.5,
	},
	"cone": {
		"name": "Conehead", "hp": 640, "speed": 26.0, "zw": 128.0, "zh": 150.0,
		"walk": "z_cone_walk", "attack": "z_cone_attack",
		"hat_hp": 300, "hat_ratio": 0.47,
		"hat_removed_walk": "z_basic_walk", "hat_removed_attack": "z_basic_attack",
		"dirty_walk": "z_losthead_walk", "dirty_attack": "z_losthead_attack",
		"dirt_ratio": 0.27,
	},
	"bucket": {
		"name": "Buckethead", "hp": 1373, "speed": 24.0, "zw": 128.0, "zh": 150.0,
		"walk": "z_bucket_walk", "attack": "z_bucket_attack",
		"hat_hp": 1100, "hat_ratio": 0.8,
		"hat_removed_walk": "z_basic_walk", "hat_removed_attack": "z_basic_attack",
		"dirty_walk": "z_losthead_walk", "dirty_attack": "z_losthead_attack",
		"dirt_ratio": 0.12,
	},
	"football": {
		"name": "Football", "hp": 1440, "speed": 46.0, "zw": 150.0, "zh": 160.0,
		"walk": "z_football_walk", "attack": "z_football_attack",
		"hat_hp": 1100, "hat_ratio": 0.76, "hat_removed_speed": 26.0,
		"hat_removed_walk": "z_basic_walk", "hat_removed_attack": "z_basic_attack",
		"dirty_walk": "z_losthead_walk", "dirty_attack": "z_losthead_attack",
		"dirt_ratio": 0.12,
	},
	"door": {
		"name": "Screen Door", "hp": 1300, "speed": 24.0, "zw": 156.0, "zh": 136.0,
		"walk": "z_door_walk", "attack": "z_door_attack",
		"hat_hp": 1000, "hat_ratio": 0.77,
		"hat_removed_walk": "z_basic_walk", "hat_removed_attack": "z_basic_attack",
		"dirty_walk": "z_losthead_walk", "dirty_attack": "z_losthead_attack",
		"dirt_ratio": 0.15,
	},
	"flag": {
		"name": "Flag Zombie", "hp": 200, "speed": 32.0, "zw": 128.0, "zh": 150.0,
		"walk": "z_basic_walk", "attack": "z_basic_attack",
		"dirty_walk": "z_losthead_walk", "dirty_attack": "z_losthead_attack",
		"dirt_ratio": 0.5, "has_flag": true,
	},
}

## 啃食参数
const ZOMBIE_BITE_INTERVAL := 0.5
const ZOMBIE_BITE_DAMAGE := 34

## 寒冰减速倍率
const SLOW_FACTOR := 0.5
const SLOW_DURATION := 5.0

## 死亡淡出时长
const ZOMBIE_DEATH_TIME := 0.9
const ZOMBIE_FAST_DEATH_TIME := 0.45

# ---------------- 波次 ----------------
## t 开始时间(秒) / z 僵尸类型列表 / huge 大波（追加旗帜僵尸与横幅）
const WAVES := [
	{"t": 18.0, "z": ["basic"]},
	{"t": 52.0, "z": ["basic", "basic"]},
	{"t": 88.0, "z": ["basic", "cone"]},
	{"t": 124.0, "z": ["basic", "basic", "cone"]},
	{"t": 160.0, "z": ["cone", "basic", "cone"], "huge": true},
	{"t": 200.0, "z": ["basic", "cone", "bucket"]},
	{"t": 240.0, "z": ["basic", "basic", "cone", "cone"]},
	{"t": 280.0, "z": ["cone", "cone", "bucket", "basic"]},
	{"t": 320.0, "z": ["cone", "bucket", "cone", "bucket"]},
	{"t": 365.0, "z": ["basic", "basic", "basic", "cone", "cone",
		"cone", "bucket", "bucket", "basic"], "huge": true},
]

## 同一波内单个僵尸的间隔(秒)
const WAVE_UNIT_GAP := 0.9

# ---------------- 小推车 ----------------
const MOWER_X := 520.0
const MOWER_DRAW := 120.0
const MOWER_SPEED := 600.0
const MOWER_TRIGGER_X := 620.0
const LOSE_X := 430.0

# ---------------- 弹道 ----------------
const PEA_SPEED := 430.0
const PEA_DRAW := 34.0
const ICE_PEA_SPEED := 430.0
const ICE_PEA_DRAW := 38.0

# ---------------- 特效尺寸 ----------------
const FX_SUN_D := 76.0
const FX_EXPLOSION_D := 300.0
const FX_FIRE_D := 152.0
const FX_BURNT_W := 130.0
const FX_BURNT_H := 260.0
const FX_FLAG_W := 92.0
const FX_FLAG_H := 64.0

## 僵尸出生点（屏幕右侧外）
const ZOMBIE_SPAWN_X := 1980.0


# ---------------- 坐标工具 ----------------
func cell_center_x(col: int) -> float:
	return GRID_X + float(col) * CELL_W + CELL_W * 0.5


func cell_center_y(row: int) -> float:
	return GRID_Y + float(row) * CELL_H + CELL_H * 0.5 - POS_OFFSET_Y


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell_center_x(cell.x), cell_center_y(cell.y))


## 世界坐标 → 格子坐标（可能越界，调用方需用 is_valid_cell 校验）
func point_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor((pos.x - GRID_X) / CELL_W)),
		int(floor((pos.y - GRID_Y) / CELL_H))
	)


func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS


func plant_data(plant_id: String) -> Dictionary:
	return PLANTS.get(plant_id, {})


func zombie_data(zombie_id: String) -> Dictionary:
	return ZOMBIES.get(zombie_id, {})


func plant_cost(plant_id: String) -> int:
	return int(plant_data(plant_id).get("cost", 0))


func plant_recharge(plant_id: String) -> float:
	return float(plant_data(plant_id).get("recharge", 0.0))