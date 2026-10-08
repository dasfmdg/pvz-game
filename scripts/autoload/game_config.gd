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
## 夜间关卡是否仍天降阳光（原作夜间不下阳光，只能靠向日葵产出）
const NIGHT_SKY_SUN_ENABLED := false
const SUNFLOWER_SUN_VALUE := 50
const SUN_LIFETIME := 12.0
## 阳光收集飞行动画：飞向 HUD 计数框的时长（秒）与终点缩放
const SUN_FLY_TIME := 0.55
const SUN_FLY_END_SCALE := 0.4

# ---------------- 植物 ----------------
## cost 价格 / hp 生命 / recharge 卡片冷却(秒) / sheet 精灵表
## dw,dh 棋盘绘制尺寸 / name 显示名
## recharge 数值对齐参考实现 js/config.js（原先为放慢节奏做过加长，现改回原值）
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
	## melonpult 的 sheet 指向静态单图素材（STATIC_TEXTURES 中的 key），无精灵表
	"melonpult": {
		"name": "Melon-pult", "cost": 300, "hp": 300, "recharge": 8.0,
		"sheet": "melon", "dw": 104.0, "dh": 131.0,
	},
}

## 卡槽顺序
const PLANT_ORDER: Array[String] = [
	"sunflower", "peashooter", "wallnut", "cherrybomb", "repeater", "jalapeno",
	"snowpea", "threepeater", "squash", "chomper", "potato_mine", "melonpult",
]

## 植物解锁关卡（1 基，语义与参考实现 js/game.js isPlantAvailable 一致：unlockLevel <= 关卡序号）
## 0 表示开局即拥有；未列出的植物按 0 处理
const PLANT_UNLOCK := {
	"sunflower": 0, "peashooter": 0, "wallnut": 3, "potato_mine": 4, "cherrybomb": 5,
	"repeater": 7, "jalapeno": 9, "snowpea": 11, "squash": 13, "chomper": 15,
	"threepeater": 17, "melonpult": 17,
}

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
	## 西瓜投手：直伤 + 3×3 溅射，命中附减速（对齐参考实现 seed.sql / js 溅射逻辑）
	"melonpult": {
		"fire_interval": 3.0, "first_fire": 0.8,
		"damage": 80, "splash_damage": 40, "slow": true,
	},
}

## 植物动画播放倍率
## SpriteFrames 默认动画帧率为 5 fps，而精灵表元数据（sprite_meta.gd）里的帧时长单位为「秒」，
## 属「相对时长」，实际时长 = 相对时长 / (帧率 × speed_scale)。取 1/5 才能让实际时长回到元数据秒数，
## 与参考实现 js/sprites-meta.js 的播放节奏一致。调大 = 更快，调小 = 更慢。
const PLANT_ANIM_SPEED_SCALE := 0.2

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
## t 开始时间(秒) / z 僵尸类型列表 / huge 大波（自动追加旗帜僵尸与横幅）
## 第 1 关波次单独提取，供 headless_sim / entity_test 等回归工具直接引用
const WAVES := [
	{"t": 20.0, "z": ["basic"]},
	{"t": 55.0, "z": ["basic", "basic"]},
	{"t": 95.0, "z": ["basic", "basic", "basic"], "huge": true},
]

## 同一波内单个僵尸的间隔(秒)
const WAVE_UNIT_GAP := 0.9

## 波次被提前清空后的加速等待区间(秒)：本波僵尸被提前全灭时不再等时间表到点，
## 而是随机等这个区间就进入下一波；若没被提前清空，则照常按 waves[*].t 到点投放
const WAVE_EARLY_MIN := 3.0
const WAVE_EARLY_MAX := 7.0

# ---------------- 关卡 ----------------
## 30 关数据与 ../pvzcode/js/levels-data.js 逐关逐波对齐
## id 关卡序号(0 基) / name 显示名 / start_sun 初始阳光 / difficulty 难度(1~8)
## waves 波次表（结构同 WAVES）/ scene 场景（缺省 "day"）
## 可用植物不逐关硬编码，由 PLANT_UNLOCK + plants_for_level(关卡序号) 生成
## 第 1 关直接引用 WAVES，保证既有回归（entity_test / headless_sim）行为可复用
const LEVELS := [
	{
		"id": 0, "name": "第1关 · 初次防守", "start_sun": 100, "difficulty": 1,
		"waves": WAVES,
	},
	{
		"id": 1, "name": "第2关 · 路障来袭", "start_sun": 75, "difficulty": 1,
		"waves": [
			{"t": 18.0, "z": ["basic"]},
			{"t": 50.0, "z": ["basic", "basic"]},
			{"t": 85.0, "z": ["basic", "cone"]},
			{"t": 125.0, "z": ["basic", "basic", "cone"]},
			{"t": 160.0, "z": ["basic", "cone", "basic", "cone"], "huge": true},
		],
	},
	{
		"id": 2, "name": "第3关 · 铁桶初现", "start_sun": 75, "difficulty": 2,
		"waves": [
			{"t": 18.0, "z": ["basic", "basic"]},
			{"t": 50.0, "z": ["basic", "cone"]},
			{"t": 85.0, "z": ["basic", "basic", "cone"]},
			{"t": 118.0, "z": ["cone", "basic", "bucket"]},
			{"t": 155.0, "z": ["basic", "cone", "basic", "cone"], "huge": true},
			{"t": 195.0, "z": ["basic", "cone", "bucket"]},
			{"t": 235.0, "z": ["cone", "basic", "cone", "bucket"], "huge": true},
		],
	},
	{
		"id": 3, "name": "第4关 · 多路来犯", "start_sun": 50, "difficulty": 2,
		"waves": [
			{"t": 18.0, "z": ["basic", "cone"]},
			{"t": 50.0, "z": ["basic", "basic", "cone"]},
			{"t": 85.0, "z": ["cone", "basic", "bucket"]},
			{"t": 122.0, "z": ["basic", "basic", "cone"]},
			{"t": 158.0, "z": ["cone", "bucket", "basic", "cone"], "huge": true},
			{"t": 198.0, "z": ["basic", "cone", "bucket", "basic"]},
			{"t": 240.0, "z": ["cone", "cone", "bucket", "basic"], "huge": true},
		],
	},
	{
		"id": 4, "name": "第5关 · 橄榄球狂潮", "start_sun": 50, "difficulty": 3,
		"waves": [
			{"t": 16.0, "z": ["basic", "basic"]},
			{"t": 45.0, "z": ["basic", "cone", "football"]},
			{"t": 78.0, "z": ["football", "basic", "basic"]},
			{"t": 112.0, "z": ["cone", "football", "basic"]},
			{"t": 148.0, "z": ["bucket", "football", "cone", "basic"], "huge": true},
			{"t": 186.0, "z": ["football", "football", "basic"]},
			{"t": 225.0, "z": ["cone", "bucket", "football", "cone"], "huge": true},
		],
	},
	{
		"id": 5, "name": "第6关 · 铁门入侵", "start_sun": 50, "difficulty": 3,
		"waves": [
			{"t": 16.0, "z": ["basic", "basic"]},
			{"t": 45.0, "z": ["basic", "door", "basic"]},
			{"t": 78.0, "z": ["cone", "door", "basic"]},
			{"t": 112.0, "z": ["door", "football", "cone"]},
			{"t": 148.0, "z": ["bucket", "door", "football", "basic"], "huge": true},
			{"t": 186.0, "z": ["door", "door", "basic", "cone"]},
			{"t": 225.0, "z": ["cone", "bucket", "door", "football"], "huge": true},
		],
	},
	{
		"id": 6, "name": "第7关 · 混编军团", "start_sun": 50, "difficulty": 3,
		"waves": [
			{"t": 16.0, "z": ["basic", "cone"]},
			{"t": 44.0, "z": ["door", "basic", "football"]},
			{"t": 76.0, "z": ["cone", "bucket", "door"]},
			{"t": 108.0, "z": ["football", "door", "cone", "basic"]},
			{"t": 142.0, "z": ["bucket", "football", "door", "basic"], "huge": true},
			{"t": 178.0, "z": ["cone", "door", "bucket", "football"]},
			{"t": 214.0, "z": ["door", "door", "football", "bucket"], "huge": true},
		],
	},
	{
		"id": 7, "name": "第8关 · 密集攻势", "start_sun": 50, "difficulty": 4,
		"waves": [
			{"t": 15.0, "z": ["basic", "basic", "cone"]},
			{"t": 42.0, "z": ["cone", "football", "door"]},
			{"t": 72.0, "z": ["bucket", "door", "football", "basic"]},
			{"t": 104.0, "z": ["football", "cone", "bucket", "door"]},
			{"t": 138.0, "z": ["door", "football", "bucket", "cone", "basic"], "huge": true},
			{"t": 174.0, "z": ["bucket", "door", "door", "football"]},
			{"t": 212.0, "z": ["cone", "football", "bucket", "door", "basic"], "huge": true},
		],
	},
	{
		"id": 8, "name": "第9关 · 铁桶堡垒", "start_sun": 50, "difficulty": 4,
		"waves": [
			{"t": 15.0, "z": ["cone", "bucket"]},
			{"t": 42.0, "z": ["bucket", "football", "door"]},
			{"t": 72.0, "z": ["cone", "bucket", "door"]},
			{"t": 104.0, "z": ["bucket", "football", "bucket", "basic"]},
			{"t": 138.0, "z": ["door", "bucket", "football", "cone", "basic"], "huge": true},
			{"t": 174.0, "z": ["bucket", "bucket", "door", "football"]},
			{"t": 212.0, "z": ["cone", "football", "bucket", "door", "bucket"], "huge": true},
		],
	},
	{
		"id": 9, "name": "第10关 · 十关试炼", "start_sun": 50, "difficulty": 4,
		"waves": [
			{"t": 15.0, "z": ["basic", "cone", "bucket"]},
			{"t": 42.0, "z": ["door", "football", "bucket"]},
			{"t": 72.0, "z": ["cone", "door", "football", "bucket"]},
			{"t": 104.0, "z": ["bucket", "football", "door", "cone", "basic"], "huge": true},
			{"t": 138.0, "z": ["football", "door", "bucket", "football"]},
			{"t": 174.0, "z": ["cone", "bucket", "door", "football", "cone"]},
			{"t": 212.0, "z": ["bucket", "door", "football", "bucket", "door"], "huge": true},
			{"t": 258.0, "z": ["cone", "bucket", "door", "football", "basic", "bucket", "basic", "door"], "huge": true},
		],
	},
	{
		"id": 10, "name": "第11关 · 寒冰射手", "start_sun": 100, "difficulty": 4,
		"waves": [
			{"t": 15.0, "z": ["basic", "cone", "football"]},
			{"t": 44.0, "z": ["door", "bucket", "football"]},
			{"t": 74.0, "z": ["cone", "football", "door", "bucket"]},
			{"t": 106.0, "z": ["bucket", "door", "football", "cone"], "huge": true},
			{"t": 140.0, "z": ["football", "bucket", "door", "cone", "basic"]},
			{"t": 178.0, "z": ["cone", "door", "bucket", "football", "basic"], "huge": true},
		],
	},
	{
		"id": 11, "name": "第12关 · 双重火力", "start_sun": 75, "difficulty": 4,
		"waves": [
			{"t": 15.0, "z": ["cone", "bucket", "door"]},
			{"t": 42.0, "z": ["bucket", "football", "door", "basic"]},
			{"t": 72.0, "z": ["cone", "door", "bucket", "football"]},
			{"t": 104.0, "z": ["football", "bucket", "door", "cone", "basic"], "huge": true},
			{"t": 138.0, "z": ["door", "football", "bucket", "cone"]},
			{"t": 174.0, "z": ["bucket", "door", "football", "bucket", "basic"], "huge": true},
			{"t": 214.0, "z": ["cone", "football", "door", "bucket", "football", "cone"], "huge": true},
		],
	},
	{
		"id": 12, "name": "第13关 · 倭瓜登场", "start_sun": 75, "difficulty": 4,
		"waves": [
			{"t": 14.0, "z": ["basic", "cone", "bucket"]},
			{"t": 40.0, "z": ["door", "football", "bucket", "basic"]},
			{"t": 70.0, "z": ["cone", "bucket", "door", "football"]},
			{"t": 102.0, "z": ["bucket", "door", "football", "cone", "basic"], "huge": true},
			{"t": 136.0, "z": ["football", "bucket", "door", "bucket"]},
			{"t": 172.0, "z": ["door", "bucket", "football", "cone", "basic"], "huge": true},
			{"t": 210.0, "z": ["bucket", "door", "football", "bucket", "cone", "door"], "huge": true},
		],
	},
	{
		"id": 13, "name": "第14关 · 食人巨口", "start_sun": 75, "difficulty": 5,
		"waves": [
			{"t": 14.0, "z": ["cone", "football", "door"]},
			{"t": 40.0, "z": ["bucket", "door", "football", "basic"]},
			{"t": 70.0, "z": ["football", "cone", "door", "bucket"]},
			{"t": 102.0, "z": ["door", "bucket", "football", "cone", "basic"], "huge": true},
			{"t": 136.0, "z": ["bucket", "football", "door", "bucket", "basic"]},
			{"t": 172.0, "z": ["cone", "bucket", "football", "door", "bucket"], "huge": true},
			{"t": 208.0, "z": ["door", "football", "bucket", "door", "football", "cone"], "huge": true},
		],
	},
	{
		"id": 14, "name": "第15关 · 绿植大赏", "start_sun": 100, "difficulty": 5,
		"waves": [
			{"t": 14.0, "z": ["basic", "cone", "bucket", "door"]},
			{"t": 40.0, "z": ["door", "football", "bucket", "cone", "basic"]},
			{"t": 70.0, "z": ["cone", "bucket", "door", "football", "door"]},
			{"t": 100.0, "z": ["football", "bucket", "door", "cone", "basic", "bucket"], "huge": true},
			{"t": 134.0, "z": ["bucket", "door", "football", "bucket", "cone"]},
			{"t": 168.0, "z": ["door", "bucket", "football", "cone", "door", "basic"], "huge": true},
			{"t": 206.0, "z": ["bucket", "football", "door", "bucket", "door", "football", "cone"], "huge": true},
		],
	},
	{
		"id": 15, "name": "第16关 · 深夜涌动", "scene": "night", "start_sun": 50, "difficulty": 5,
		"waves": [
			{"t": 13.0, "z": ["door", "football", "cone"]},
			{"t": 38.0, "z": ["bucket", "door", "football", "basic"]},
			{"t": 66.0, "z": ["football", "cone", "door", "bucket"]},
			{"t": 96.0, "z": ["door", "football", "bucket", "cone", "basic"], "huge": true},
			{"t": 130.0, "z": ["bucket", "door", "football", "bucket"]},
			{"t": 164.0, "z": ["cone", "football", "door", "bucket", "door"], "huge": true},
			{"t": 200.0, "z": ["football", "bucket", "door", "football", "cone", "bucket"], "huge": true},
		],
	},
	{
		"id": 16, "name": "第17关 · 三重火力", "start_sun": 100, "difficulty": 5,
		"waves": [
			{"t": 13.0, "z": ["cone", "door", "football"]},
			{"t": 38.0, "z": ["bucket", "football", "door", "cone"]},
			{"t": 66.0, "z": ["door", "bucket", "football", "cone", "basic"]},
			{"t": 96.0, "z": ["football", "bucket", "door", "bucket", "basic"], "huge": true},
			{"t": 130.0, "z": ["bucket", "door", "football", "cone", "door"]},
			{"t": 164.0, "z": ["cone", "bucket", "door", "football", "bucket"], "huge": true},
			{"t": 200.0, "z": ["door", "football", "bucket", "door", "football", "cone", "bucket"], "huge": true},
			{"t": 240.0, "z": ["bucket", "door", "football", "bucket", "cone", "door", "basic", "football"], "huge": true},
		],
	},
	{
		"id": 17, "name": "第18关 · 全能火力", "start_sun": 50, "difficulty": 5,
		"waves": [
			{"t": 13.0, "z": ["basic", "cone", "door", "football"]},
			{"t": 38.0, "z": ["bucket", "football", "door", "cone", "basic"]},
			{"t": 66.0, "z": ["door", "bucket", "football", "cone"]},
			{"t": 96.0, "z": ["football", "bucket", "door", "cone", "basic", "bucket"], "huge": true},
			{"t": 130.0, "z": ["bucket", "door", "football", "bucket", "door"]},
			{"t": 164.0, "z": ["cone", "football", "door", "bucket", "football"], "huge": true},
			{"t": 200.0, "z": ["door", "bucket", "football", "cone", "door", "bucket"], "huge": true},
		],
	},
	{
		"id": 18, "name": "第19关 · 钢铁洪流", "start_sun": 50, "difficulty": 6,
		"waves": [
			{"t": 12.0, "z": ["bucket", "door", "football"]},
			{"t": 36.0, "z": ["door", "bucket", "football", "cone"]},
			{"t": 64.0, "z": ["football", "bucket", "door", "bucket"]},
			{"t": 92.0, "z": ["bucket", "football", "door", "cone", "basic"], "huge": true},
			{"t": 126.0, "z": ["door", "bucket", "football", "bucket", "door"]},
			{"t": 160.0, "z": ["bucket", "door", "football", "cone", "bucket"], "huge": true},
			{"t": 196.0, "z": ["football", "bucket", "door", "football", "door", "cone"], "huge": true},
		],
	},
	{
		"id": 19, "name": "第20关 · 二十年试炼", "start_sun": 100, "difficulty": 6,
		"waves": [
			{"t": 12.0, "z": ["basic", "cone", "bucket", "door", "football"]},
			{"t": 36.0, "z": ["door", "football", "bucket", "cone", "basic"]},
			{"t": 64.0, "z": ["cone", "bucket", "door", "football", "door", "basic"]},
			{"t": 94.0, "z": ["football", "bucket", "door", "cone", "basic", "bucket"], "huge": true},
			{"t": 128.0, "z": ["bucket", "door", "football", "bucket", "door", "cone"]},
			{"t": 162.0, "z": ["door", "football", "bucket", "cone", "door", "bucket"], "huge": true},
			{"t": 198.0, "z": ["bucket", "door", "football", "bucket", "door", "football", "cone", "basic"], "huge": true},
		],
	},
	{
		"id": 20, "name": "第21关 · 橄榄球夜袭", "scene": "night", "start_sun": 50, "difficulty": 6,
		"waves": [
			{"t": 12.0, "z": ["football", "basic", "cone"]},
			{"t": 34.0, "z": ["door", "football", "bucket", "basic"]},
			{"t": 60.0, "z": ["football", "cone", "door", "bucket"]},
			{"t": 90.0, "z": ["bucket", "football", "door", "cone", "basic"], "huge": true},
			{"t": 122.0, "z": ["football", "door", "football", "bucket"]},
			{"t": 154.0, "z": ["cone", "football", "door", "football", "bucket"], "huge": true},
			{"t": 188.0, "z": ["football", "bucket", "door", "football", "cone", "door"], "huge": true},
		],
	},
	{
		"id": 21, "name": "第22关 · 铁桶浪潮", "start_sun": 75, "difficulty": 6,
		"waves": [
			{"t": 12.0, "z": ["bucket", "cone", "door"]},
			{"t": 34.0, "z": ["door", "bucket", "football", "cone"]},
			{"t": 60.0, "z": ["bucket", "football", "door", "bucket"]},
			{"t": 90.0, "z": ["door", "bucket", "football", "cone", "basic"], "huge": true},
			{"t": 122.0, "z": ["bucket", "door", "football", "bucket", "door"]},
			{"t": 154.0, "z": ["cone", "bucket", "football", "door", "bucket"], "huge": true},
			{"t": 188.0, "z": ["bucket", "door", "bucket", "football", "cone", "door"], "huge": true},
		],
	},
	{
		"id": 22, "name": "第23关 · 混血大军", "start_sun": 50, "difficulty": 6,
		"waves": [
			{"t": 11.0, "z": ["basic", "cone", "door", "football", "bucket"]},
			{"t": 32.0, "z": ["door", "football", "bucket", "cone", "basic"]},
			{"t": 58.0, "z": ["cone", "bucket", "door", "football", "door"]},
			{"t": 88.0, "z": ["football", "bucket", "door", "cone", "basic", "bucket"], "huge": true},
			{"t": 120.0, "z": ["bucket", "door", "football", "bucket", "door", "cone"]},
			{"t": 152.0, "z": ["door", "football", "bucket", "cone", "door", "bucket"], "huge": true},
			{"t": 186.0, "z": ["bucket", "door", "football", "bucket", "door", "football", "cone", "basic"], "huge": true},
		],
	},
	{
		"id": 23, "name": "第24关 · 围攻之局", "scene": "night", "start_sun": 50, "difficulty": 7,
		"waves": [
			{"t": 11.0, "z": ["door", "football", "bucket", "cone"]},
			{"t": 32.0, "z": ["bucket", "football", "door", "cone", "basic"]},
			{"t": 58.0, "z": ["football", "cone", "bucket", "door", "football"]},
			{"t": 88.0, "z": ["door", "bucket", "football", "cone", "basic", "bucket"], "huge": true},
			{"t": 120.0, "z": ["bucket", "door", "football", "bucket", "door"]},
			{"t": 152.0, "z": ["cone", "football", "door", "bucket", "football", "door"], "huge": true},
			{"t": 186.0, "z": ["door", "bucket", "football", "door", "bucket", "cone", "basic"], "huge": true},
		],
	},
	{
		"id": 24, "name": "第25关 · 疯狂冲刺", "start_sun": 100, "difficulty": 7,
		"waves": [
			{"t": 10.0, "z": ["basic", "cone", "door", "football"]},
			{"t": 30.0, "z": ["bucket", "football", "door", "cone", "basic"]},
			{"t": 54.0, "z": ["door", "bucket", "football", "cone", "door"]},
			{"t": 82.0, "z": ["football", "bucket", "door", "cone", "basic", "bucket"], "huge": true},
			{"t": 112.0, "z": ["bucket", "door", "football", "bucket", "door", "cone"]},
			{"t": 144.0, "z": ["door", "football", "bucket", "cone", "door", "bucket"], "huge": true},
			{"t": 176.0, "z": ["bucket", "door", "football", "bucket", "door", "football", "cone", "basic"], "huge": true},
		],
	},
	{
		"id": 25, "name": "第26关 · 尸潮终夜", "scene": "night", "start_sun": 50, "difficulty": 7,
		"waves": [
			{"t": 10.0, "z": ["football", "door", "bucket", "basic"]},
			{"t": 28.0, "z": ["bucket", "football", "door", "cone", "basic"]},
			{"t": 52.0, "z": ["door", "bucket", "football", "cone", "door", "basic"]},
			{"t": 80.0, "z": ["football", "bucket", "door", "cone", "basic", "bucket"], "huge": true},
			{"t": 110.0, "z": ["bucket", "door", "football", "bucket", "door", "cone"]},
			{"t": 140.0, "z": ["door", "football", "bucket", "cone", "door", "bucket"], "huge": true},
			{"t": 172.0, "z": ["bucket", "door", "football", "bucket", "door", "football", "cone", "basic", "bucket"], "huge": true},
		],
	},
	{
		"id": 26, "name": "第27关 · 绝望防御", "start_sun": 75, "difficulty": 7,
		"waves": [
			{"t": 10.0, "z": ["cone", "bucket", "door", "football"]},
			{"t": 28.0, "z": ["door", "bucket", "football", "cone", "basic", "door"]},
			{"t": 52.0, "z": ["bucket", "football", "door", "cone", "door", "bucket"]},
			{"t": 80.0, "z": ["football", "bucket", "door", "cone", "basic", "bucket", "door"], "huge": true},
			{"t": 110.0, "z": ["bucket", "door", "football", "bucket", "door", "cone"]},
			{"t": 140.0, "z": ["door", "football", "bucket", "cone", "door", "bucket", "football"], "huge": true},
			{"t": 172.0, "z": ["bucket", "door", "football", "bucket", "door", "football", "cone", "basic", "bucket", "door"], "huge": true},
		],
	},
	{
		"id": 27, "name": "第28关 · 终极火线", "scene": "night", "start_sun": 50, "difficulty": 8,
		"waves": [
			{"t": 10.0, "z": ["door", "bucket", "football", "cone", "basic"]},
			{"t": 28.0, "z": ["bucket", "football", "door", "cone", "door", "bucket"]},
			{"t": 52.0, "z": ["football", "bucket", "door", "football", "cone", "basic"]},
			{"t": 78.0, "z": ["bucket", "door", "football", "cone", "basic", "bucket", "door"], "huge": true},
			{"t": 108.0, "z": ["door", "bucket", "football", "bucket", "door", "cone"]},
			{"t": 138.0, "z": ["football", "door", "bucket", "cone", "door", "bucket", "football"], "huge": true},
			{"t": 170.0, "z": ["bucket", "door", "football", "bucket", "door", "football", "cone", "basic", "bucket"], "huge": true},
		],
	},
	{
		"id": 28, "name": "第29关 · 死亡进军", "start_sun": 100, "difficulty": 8,
		"waves": [
			{"t": 9.0, "z": ["cone", "bucket", "door", "football", "basic"]},
			{"t": 26.0, "z": ["bucket", "football", "door", "cone", "door", "bucket"]},
			{"t": 48.0, "z": ["door", "bucket", "football", "door", "cone", "basic", "bucket"]},
			{"t": 74.0, "z": ["football", "bucket", "door", "cone", "basic", "bucket", "door"], "huge": true},
			{"t": 102.0, "z": ["bucket", "door", "football", "bucket", "door", "cone", "football"]},
			{"t": 130.0, "z": ["door", "football", "bucket", "cone", "door", "bucket", "door"], "huge": true},
			{"t": 160.0, "z": ["bucket", "door", "football", "bucket", "door", "football", "cone", "basic", "bucket", "door"], "huge": true},
			{"t": 190.0, "z": ["football", "door", "bucket", "door", "football", "bucket", "cone", "basic", "bucket", "door"], "huge": true},
		],
	},
	{
		"id": 29, "name": "第30关 · 终局之战", "scene": "night", "start_sun": 100, "difficulty": 8,
		"waves": [
			{"t": 9.0, "z": ["door", "bucket", "football", "cone", "basic", "door"]},
			{"t": 26.0, "z": ["bucket", "football", "door", "cone", "door", "bucket", "football"]},
			{"t": 48.0, "z": ["door", "bucket", "football", "door", "cone", "basic", "bucket", "door"]},
			{"t": 72.0, "z": ["football", "bucket", "door", "cone", "basic", "bucket", "door", "football"], "huge": true},
			{"t": 100.0, "z": ["bucket", "door", "football", "bucket", "door", "cone", "football", "bucket"]},
			{"t": 128.0, "z": ["door", "football", "bucket", "cone", "door", "bucket", "door", "football"], "huge": true},
			{"t": 158.0, "z": ["bucket", "door", "football", "bucket", "door", "football", "cone", "basic", "bucket", "door"], "huge": true},
			{"t": 188.0, "z": ["football", "bucket", "door", "football", "door", "bucket", "cone", "basic", "bucket", "door", "football"], "huge": true},
			{"t": 220.0, "z": ["bucket", "door", "football", "bucket", "door", "football", "cone", "basic", "bucket", "door", "football", "cone"], "huge": true},
		],
	},
]

# ---------------- 场景（白天 / 夜晚） ----------------
const SCENE_DAY := "day"
const SCENE_NIGHT := "night"
## 夜间草坪色调：只对背景贴图做 modulate，不压暗实体与界面
const NIGHT_LAWN_TINT := Color(0.42, 0.5, 0.74)
## 夜间草坪素材：与 lawn.png 同构图的夜景版本
## 文件缺失时自动回退 lawn.png + NIGHT_LAWN_TINT，不阻断游戏
const NIGHT_LAWN_PATH := "res://assets/lawn_night.png"


## 关卡数据（index 0 基，越界返回空字典）
func level_data(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	return LEVELS[index]


func level_scene(index: int) -> String:
	return String(level_data(index).get("scene", SCENE_DAY))


func level_is_night(index: int) -> bool:
	return level_scene(index) == SCENE_NIGHT


## 关卡可用植物（level_id 为 1 基）：PLANT_UNLOCK 中 unlockLevel <= level_id 的植物全部开放
func plants_for_level(level_id: int) -> Array[String]:
	var result: Array[String] = []
	for plant_id in PLANT_ORDER:
		if int(PLANT_UNLOCK.get(plant_id, 0)) <= level_id:
			result.append(plant_id)
	return result


# ---------------- 选卡界面 ----------------
## 槽位上限 = min(已解锁植物数, SEED_SLOT_BASE + 每 SEED_SLOT_STEP 关 +1, SEED_SLOT_MAX)
## 早期关卡 unlocked 小于公式值，自动退化为「全带」；后期才出现真正的取舍
const SEED_SLOT_BASE := 5
const SEED_SLOT_STEP := 4
## 与主控数字键 1~9/0 的 10 张上界对齐
const SEED_SLOT_MAX := 10

## 第几关起需要经过选卡界面（1 基；第 1~6 关仍直接进关，保持快速启动）
const SEED_SELECT_FROM_LEVEL := 7

## 僵尸显示中文名（图鉴沿用英文 name，此处单独维护一份选卡界面用词）
const ZOMBIE_NAMES_CN := {
	"basic": "普通僵尸", "cone": "路障僵尸", "bucket": "铁桶僵尸",
	"football": "橄榄球僵尸", "door": "铁门僵尸", "flag": "旗帜僵尸",
}


## 本关可携带卡片槽位上限（level_id 为 1 基，返回值恒在 1~SEED_SLOT_MAX）
func seed_slot_limit(level_id: int) -> int:
	var unlocked := plants_for_level(level_id).size()
	var grown := SEED_SLOT_BASE + int(floor(float(maxi(level_id - 1, 0)) / float(SEED_SLOT_STEP)))
	return clampi(mini(unlocked, mini(grown, SEED_SLOT_MAX)), 1, SEED_SLOT_MAX)


## 是否需要先经过选卡界面（index 为 0 基）
func level_needs_seed_select(index: int) -> bool:
	return index + 1 >= SEED_SELECT_FROM_LEVEL


## 本关会出现的僵尸种类（index 0 基，按首次出现顺序去重）
## include_flag 默认关闭：大波（huge）自动追加的旗帜僵尸只是节奏标记，不计入种类展示
func zombies_for_level(index: int, include_flag := false) -> Array[String]:
	var result: Array[String] = []
	var data := level_data(index)
	if data.is_empty():
		return result
	for raw_wave in data["waves"] as Array:
		var wave := raw_wave as Dictionary
		var kinds: Array = (wave.get("z", []) as Array).duplicate()
		if include_flag and bool(wave.get("huge", false)):
			kinds.append("flag")
		for raw_id in kinds:
			var zombie_id := String(raw_id)
			if not include_flag and zombie_id == "flag":
				continue
			if not ZOMBIES.has(zombie_id) or result.has(zombie_id):
				continue
			result.append(zombie_id)
	return result


## 僵尸中文名：优先中文表，其次 ZOMBIES 英文名，最后回退 id（保证非空）
func zombie_name_cn(zombie_id: String) -> String:
	if ZOMBIE_NAMES_CN.has(zombie_id):
		return String(ZOMBIE_NAMES_CN[zombie_id])
	var data := zombie_data(zombie_id)
	if data.has("name"):
		return String(data["name"])
	return zombie_id


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
## 西瓜投手弹道：melon.png 为 50×63 静态单图，绘制尺寸按等比取 46×58
const MELON_SPEED := 300.0
const MELON_DRAW_W := 46.0
const MELON_DRAW_H := 58.0
## 投掷弧线振幅（像素）：仅叠加在弹体视觉纵向上，不参与命中判定
const MELON_ARC_HEIGHT := 34.0

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