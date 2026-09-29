class_name UiKit
extends RefCounted
## 界面层公共工具：中文字体、贴图安全加载、常用控件构建
## 全部界面用代码构建 Control 节点，不依赖 .tscn 手写节点树

## 打包中文字体（Web 导出环境无系统字体，必须自带字形子集）
const PACKED_FONT_PATH := "res://assets/fonts/pvz_ui.ttf"

## 中文字体候选（桌面端回退：按系统可用性取系统字体）
const CJK_FONTS: Array[String] = [
	"Microsoft YaHei", "Microsoft YaHei UI", "SimHei", "SimSun",
	"PingFang SC", "Noto Sans CJK SC", "WenQuanYi Micro Hei", "sans-serif",
]

static var _font: Font = null


## 中文字体（惰性创建并缓存）：优先打包字体，缺失时回退系统字体
static func font() -> Font:
	if _font != null:
		return _font
	if ResourceLoader.exists(PACKED_FONT_PATH):
		var packed := load(PACKED_FONT_PATH) as Font
		if packed != null:
			_font = packed
			return _font
	var system_font := SystemFont.new()
	var names := PackedStringArray()
	for font_name in CJK_FONTS:
		names.append(font_name)
	system_font.font_names = names
	_font = system_font
	return _font


## 安全加载贴图：资源缺失返回 null，不阻断界面构建
static func load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("[UiKit] 贴图不存在：%s" % path)
		return null
	return load(path) as Texture2D


## 精灵表首帧裁切（用于没有独立立绘的僵尸）
static func sheet_first_frame(sheet: String) -> AtlasTexture:
	var meta: Dictionary = SpriteMeta.SHEETS.get(sheet, {})
	if meta.is_empty():
		return null
	var tex := SpriteLibrary.texture(String(meta["src"]))
	if tex == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(0.0, 0.0, float(meta["w"]), float(meta["h"]))
	return atlas


static func make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func make_button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", font())
	button.add_theme_font_size_override("font_size", font_size)
	button.focus_mode = Control.FOCUS_NONE
	return button


## 铺满父容器的贴图控件
static func make_texture(path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load_texture(path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect