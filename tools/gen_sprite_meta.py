#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""生成 Godot 精灵表帧元数据（scripts/data/sprite_meta.gd）。

来源：参考工程的 js/sprites-meta.js（横向精灵表，帧宽高一致）。
用法：
    python tools/gen_sprite_meta.py <sprites-meta.js 路径> [输出 .gd 路径]
默认输入 ../pvzcode/js/sprites-meta.js，默认输出 scripts/data/sprite_meta.gd。
"""
import os
import re
import sys

DEFAULT_SRC = os.path.join("..", "pvzcode", "js", "sprites-meta.js")
DEFAULT_OUT = os.path.join("scripts", "data", "sprite_meta.gd")

## 本地追加精灵表：来源 tools/build_sheets.py 生成，参考工程 sprites-meta.js 中没有。
## 元组含义：(名称, 帧宽, 帧高, 帧数, 单帧时长秒, assets 下相对路径)
## 名称与 sprites-meta.js 冲突时以本表为准（参考工程若后续补齐同名表，这里会覆盖）。
EXTRA_SHEETS = [
    ## 撑杆僵尸：统一画布 300x176，脚底基线 y=170，绘制尺寸与原始像素 1:1
    ("z_pole_walk", 300, 176, 10, 0.18, "sprites/z_pole_walk.png"),
    ("z_pole_attack", 300, 176, 14, 0.09, "sprites/z_pole_attack.png"),
    ("z_pole_jump", 300, 176, 10, 0.05, "sprites/z_pole_jump.png"),
    ("z_pole_after_jump", 300, 176, 26, 0.18, "sprites/z_pole_after_jump.png"),
    ("z_pole_losthead", 300, 176, 10, 0.07, "sprites/z_pole_losthead.png"),
    ## 报纸僵尸：统一画布 120x164（原始 216x164 裁掉两侧留白，白底已键控）
    ("z_newspaper_walk", 120, 164, 19, 0.18, "sprites/z_newspaper_walk.png"),
    ("z_newspaper_attack", 120, 164, 8, 0.09, "sprites/z_newspaper_attack.png"),
    ("z_newspaper_rip", 120, 164, 15, 0.06, "sprites/z_newspaper_rip.png"),
    ("z_newspaper_nopaper_walk", 120, 164, 14, 0.18,
     "sprites/z_newspaper_nopaper_walk.png"),
    ("z_newspaper_nopaper_attack", 120, 164, 7, 0.09,
     "sprites/z_newspaper_nopaper_attack.png"),
    ("z_newspaper_losthead", 120, 164, 16, 0.07, "sprites/z_newspaper_losthead.png"),
    ## 甜菜：待机 2 帧 / 枯萎 3 帧
    ("beetroot", 55, 75, 2, 0.3, "sprites/beetroot.png"),
    ("beetroot_dying", 55, 75, 3, 0.15, "sprites/beetroot_dying.png"),
]


def split_top_level(text):
    """按顶层逗号切分参数，忽略括号与中括号内部的逗号。"""
    parts = []
    depth = 0
    current = []
    for ch in text:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append("".join(current).strip())
            current = []
            continue
        current.append(ch)
    tail = "".join(current).strip()
    if tail:
        parts.append(tail)
    return parts


def match_paren(text, open_index):
    """返回与 text[open_index]=='(' 匹配的右括号位置。"""
    depth = 0
    for i in range(open_index, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    raise ValueError("括号不匹配: %s" % text[open_index:open_index + 40])


def eval_delays(expr):
    """解析 delays 表达式：rep / tail / 字面量数组 / 数组.concat(rep)。"""
    expr = expr.strip()
    if expr.startswith("rep("):
        args = split_top_level(expr[4:match_paren(expr, 3)])
        n = int(args[0])
        value = int(args[1])
        return [value] * n
    if expr.startswith("tail("):
        args = split_top_level(expr[5:match_paren(expr, 4)])
        n = int(args[0])
        value = int(args[1])
        last = int(args[2])
        return [value] * n + [last]
    if expr.startswith("[") and ".concat(" in expr:
        head, rest = expr.split(".concat(", 1)
        head_list = [int(x.strip()) for x in head.strip("[] ").split(",") if x.strip()]
        # 去掉 concat 自身的收尾右括号
        inner = rest[:-1] if rest.endswith(")") else rest
        return head_list + eval_delays(inner)
    if expr.startswith("["):
        body = expr[1:expr.rindex("]")]
        return [int(x.strip()) for x in body.split(",") if x.strip()]
    raise ValueError("无法解析 delays 表达式: %s" % expr)


def png_size(path):
    """读取 PNG 宽高（IHDR），无需第三方库。"""
    with open(path, "rb") as handle:
        head = handle.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("不是合法 PNG：%s" % path)
    width = int.from_bytes(head[16:20], "big")
    height = int.from_bytes(head[20:24], "big")
    return width, height


def parse_meta(js_text, assets_dir):
    entries = []
    pattern = re.compile(r'"([A-Za-z0-9_]+)"\s*:\s*def\(')
    for match in pattern.finditer(js_text):
        name = match.group(1)
        open_index = match.end() - 1
        close_index = match_paren(js_text, open_index)
        args = split_top_level(js_text[open_index + 1:close_index])
        if len(args) != 5:
            raise ValueError("def() 参数个数异常: %s -> %s" % (name, args))
        w = int(args[0])
        h = int(args[1])
        declared_frames = int(args[2])
        delays = eval_delays(args[3])
        src = args[4].strip().strip('"')
        frames = declared_frames
        png_path = os.path.join(assets_dir, src.replace("/", os.sep))
        if os.path.isfile(png_path) and w > 0:
            width, _height = png_size(png_path)
            actual = width // w
            if actual != declared_frames:
                print("[告警] %s 声明 %d 帧，图片实际 %d 帧，以图片为准"
                      % (name, declared_frames, actual))
            frames = actual
        if len(delays) > frames:
            print("[告警] %s delays 比帧数多 %d 项，已截断" % (name, len(delays) - frames))
            delays = delays[:frames]
        while len(delays) < frames:
            delays.append(delays[-1] if delays else 100)
        entries.append((name, w, h, frames, delays, src))
    return entries


def merge_extra(entries):
    """把 EXTRA_SHEETS（tools/build_sheets.py 产物）并入元数据表。"""
    merged = [(name, w, h, frames, delays, src) for name, w, h, frames, delays, src in entries]
    for name, w, h, frames, delay_second, src in EXTRA_SHEETS:
        delays = [int(round(delay_second * 1000))] * frames
        merged.append((name, w, h, frames, delays, src))
    ## 追加表排在被覆盖表之后，emit 时按名称去重保留最后一条
    result = []
    seen = set()
    for entry in reversed(merged):
        if entry[0] in seen:
            continue
        seen.add(entry[0])
        result.append(entry)
    result.reverse()
    return result


def uniform_delay(delays):
    first = delays[0]
    for value in delays:
        if value != first:
            return None
    return first


def emit_gd(entries):
    lines = [
        "class_name SpriteMeta",
        "extends RefCounted",
        "## 自动生成，请勿手改：精灵表帧元数据（横向精灵表，帧宽高一致）",
        "## 生成命令：python tools/gen_sprite_meta.py ../pvzcode/js/sprites-meta.js",
        "",
        "const SHEETS := {",
    ]
    for name, w, h, frames, delays, src in entries:
        delay_second = [round(value / 1000.0, 4) for value in delays]
        uniform = uniform_delay(delay_second)
        res_path = "res://assets/" + src.replace("\\", "/")
        if uniform is not None:
            timing = '"d": %s' % repr(uniform)
        else:
            timing = '"delays": [%s]' % ", ".join(repr(value) for value in delay_second)
        lines.append(
            '\t"%s": {"w": %d, "h": %d, "frames": %d, %s, "src": "%s"},'
            % (name, w, h, frames, timing, res_path)
        )
    lines += [
        "}",
        "",
        "",
        "## 取某张精灵表的逐帧时长（秒）",
        "static func delays(sheet: String) -> Array[float]:",
        "\tvar out: Array[float] = []",
        "\tvar meta: Dictionary = SHEETS.get(sheet, {})",
        "\tif meta.is_empty():",
        "\t\treturn out",
        "\tif meta.has(\"delays\"):",
        "\t\tfor value in meta[\"delays\"]:",
        "\t\t\tout.append(float(value))",
        "\t\treturn out",
        "\tvar uniform := float(meta[\"d\"])",
        "\tfor i in int(meta[\"frames\"]):",
        "\t\tout.append(uniform)",
        "\treturn out",
        "",
        "",
        "## 取某张精灵表的单帧尺寸",
        "static func frame_size(sheet: String) -> Vector2:",
        "\tvar meta: Dictionary = SHEETS.get(sheet, {})",
        "\tif meta.is_empty():",
        "\t\treturn Vector2.ONE",
        "\treturn Vector2(float(meta[\"w\"]), float(meta[\"h\"]))",
        "",
    ]
    return "\n".join(lines)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    out = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_OUT
    if not os.path.isfile(src):
        print("找不到输入文件：%s" % os.path.abspath(src))
        return 1
    assets_dir = os.path.join(os.path.dirname(os.path.abspath(out)), "..", "assets")
    assets_dir = os.path.normpath(assets_dir)
    with open(src, "r", encoding="utf-8") as handle:
        js_text = handle.read()
    entries = parse_meta(js_text, assets_dir)
    entries = merge_extra(entries)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(emit_gd(entries))
    print("已生成 %s，共 %d 张精灵表" % (out, len(entries)))
    return 0


if __name__ == "__main__":
    sys.exit(main())