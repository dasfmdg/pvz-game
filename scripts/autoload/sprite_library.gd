extends Node
## 精灵表资源库：把「横向精灵表 PNG」切分为 SpriteFrames，并做纹理/动画缓存
## 元数据来源：scripts/data/sprite_meta.gd（由 tools/gen_sprite_meta.py 生成，禁止手改）

## 静态图片（非精灵表）
const STATIC_TEXTURES := {
	"lawn": "res://assets/lawn.png",
	"pea": "res://assets/pea.png",
	"sun": "res://assets/sun.png",
	"shovel": "res://assets/shovel.png",
	"flag": "res://assets/flag.png",
	"melon": "res://assets/melon.png",
}

## 卡片图（植物 id → 图片）
const CARD_TEXTURES := {
	"sunflower": "res://assets/card_sunflower.png",
	"peashooter": "res://assets/card_peashooter.png",
	"wallnut": "res://assets/card_wallnut.png",
	"cherrybomb": "res://assets/card_cherrybomb.png",
	"repeater": "res://assets/card_repeater.png",
	"jalapeno": "res://assets/card_jalapeno.png",
	"snowpea": "res://assets/card_snowpea.png",
	"threepeater": "res://assets/card_threepeater.png",
	"potato_mine": "res://assets/card_potato_mine.png",
	"squash": "res://assets/card_squash.png",
	"chomper": "res://assets/card_chomper.png",
}

var _texture_cache: Dictionary = {}
var _frames_cache: Dictionary = {}


## 读取单帧原始尺寸（精灵表单元格尺寸）
func sheet_size(sheet_name: String) -> Vector2:
	var meta: Dictionary = SpriteMeta.SHEETS.get(sheet_name, {})
	if meta.is_empty():
		push_warning("[SpriteLibrary] 未找到精灵表元数据：%s" % sheet_name)
		return Vector2(1, 1)
	return Vector2(float(meta["w"]), float(meta["h"]))


func texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("[SpriteLibrary] 纹理加载失败：%s" % path)
	_texture_cache[path] = tex
	return tex


func static_texture(key: String) -> Texture2D:
	return texture(String(STATIC_TEXTURES.get(key, "")))


func card_texture(plant_id: String) -> Texture2D:
	return texture(String(CARD_TEXTURES.get(plant_id, "")))


## 构建动画集：anim_sheets = { 动画名: 精灵表名 }，once_anims 中的动画只播放一次
func frames_for(anim_sheets: Dictionary, once_anims: Array = []) -> SpriteFrames:
	var cache_key := "%s|%s" % [str(anim_sheets), str(once_anims)]
	if _frames_cache.has(cache_key):
		return _frames_cache[cache_key]

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim_name: String in anim_sheets.keys():
		var sheet_name: String = String(anim_sheets[anim_name])
		_build_animation(frames, anim_name, sheet_name)
		frames.set_animation_loop(anim_name, not once_anims.has(anim_name))
	_frames_cache[cache_key] = frames
	return frames


func _build_animation(frames: SpriteFrames, anim_name: String, sheet_name: String) -> void:
	var meta: Dictionary = SpriteMeta.SHEETS.get(sheet_name, {})
	if meta.is_empty():
		push_warning("[SpriteLibrary] 精灵表不存在：%s" % sheet_name)
		return
	var tex := texture(String(meta["src"]))
	if tex == null:
		return
	frames.add_animation(anim_name)
	var w := float(meta["w"])
	var h := float(meta["h"])
	var delays := SpriteMeta.delays(sheet_name)
	for i in delays.size():
		var region := AtlasTexture.new()
		region.atlas = tex
		region.region = Rect2(float(i) * w, 0.0, w, h)
		frames.add_frame(anim_name, region, delays[i])


## 创建逐帧动画精灵：按「首帧原始尺寸 → 目标绘制尺寸」等比缩放
func make_sprite(anim_sheets: Dictionary, draw_w: float, draw_h: float,
		once_anims: Array = [], first_anim := "") -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames_for(anim_sheets, once_anims)
	var base_sheet: String = String(anim_sheets.values()[0])
	var size := sheet_size(base_sheet)
	sprite.scale = Vector2(draw_w / size.x, draw_h / size.y)
	var anim_names := anim_sheets.keys()
	if first_anim.is_empty():
		first_anim = String(anim_names[0])
	if sprite.sprite_frames.has_animation(first_anim):
		sprite.animation = first_anim
		sprite.play()
	return sprite


## 创建普通精灵（非精灵表）
func make_static_sprite(key: String, draw_w: float, draw_h: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	var tex := static_texture(key)
	sprite.texture = tex
	if tex != null and tex.get_width() > 0 and tex.get_height() > 0:
		sprite.scale = Vector2(draw_w / float(tex.get_width()), draw_h / float(tex.get_height()))
	return sprite