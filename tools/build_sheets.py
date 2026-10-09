#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""构建 pvz-game 使用的追加精灵表与卡图（一次性素材构建脚本，不在运行时执行）。

用法：
    python tools/build_sheets.py

输入：
    %TEMP%/pypvz.zip                     撑杆僵尸 / 报纸僵尸 原始逐帧 PNG
    tools/_preview/beetroot.gif          甜菜待机（2 帧）
    tools/_preview/beetroot_dying.gif    甜菜枯萎（3 帧）
    tools/_preview/beetbullet.png        甜菜子弹
    tools/_preview/active_beetroot.png   甜菜卡面素体

输出：
    assets/sprites/z_pole_*.png          撑杆僵尸 5 张表，统一画布 300x176，脚底基线 y=170
    assets/sprites/z_newspaper_*.png     报纸僵尸 6 张表，统一画布 120x164
    assets/sprites/beetroot.png          甜菜待机表
    assets/sprites/beetroot_dying.png    甜菜枯萎表
    assets/beetbullet.png                甜菜子弹静态图
    assets/card_beetroot.png             甜菜卡图 64x89
    assets/card_newspaper.png            报纸僵尸卡图 64x89

构建完成后必须执行：
    python tools/gen_sprite_meta.py
说明：
    报纸僵尸除 NewspaperZombieLostNewspaper 外的原始帧为「纯白不透明底」，
    这里统一做白底键控（阈值 238），否则游戏里会画出白方块。
    撑杆僵尸原始帧已带 alpha，不做键控。
    撑杆僵尸各原始动画画布尺寸差异极大（95x144 / 201x144 / 288x174），
    这里统一重排到同一画布并统一脚底基线，保证 AnimatedSprite2D 单倍缩放可用。
"""
import io
import os
import sys
import zipfile

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(ROOT, "assets")
SPRITES_DIR = os.path.join(ASSETS_DIR, "sprites")
PREVIEW_DIR = os.path.join(ROOT, "tools", "_preview")
ZOMBIE_ZIP = os.path.join(os.environ.get("TEMP", "/tmp"), "pypvz.zip")
ZOMBIE_ROOT = "pypvz-master/resources/graphics/Zombies/"

## 白底键控阈值：min(r,g,b) >= 该值视为背景
WHITE_KEY_MIN = 238

## 撑杆僵尸统一画布与脚底基线
POLE_CANVAS = (300, 176)
POLE_BASELINE = 170
## (输出名, zip 内子目录, 是否逐帧水平居中)
## 逐帧居中用于跳跃动画：原始帧把「腾挪位移」烘焙在 288 宽画布内，
## 这里把它消掉，改由 GDScript 按固定距离推进位置，避免与逻辑位移叠加。
POLE_ANIMS = [
    ("z_pole_walk", "PoleVaultingZombie/PoleVaultingZombie", False),
    ("z_pole_attack", "PoleVaultingZombie/PoleVaultingZombieAttack", False),
    ("z_pole_jump", "PoleVaultingZombie/PoleVaultingZombieJump", True),
    ("z_pole_after_jump", "PoleVaultingZombie/PoleVaultingZombieWalkAfterJump", False),
    ("z_pole_losthead", "PoleVaultingZombie/PoleVaultingZombieLostHead", False),
]

## 报纸僵尸统一裁切窗口（原始帧 216x164，主体恒定落在 x 32..152）
NEWSPAPER_CROP = (32, 0, 152, 164)
NEWSPAPER_ANIMS = [
    ("z_newspaper_walk", "NewspaperZombie/NewspaperZombie", True),
    ("z_newspaper_attack", "NewspaperZombie/NewspaperZombieAttack", True),
    ("z_newspaper_rip", "NewspaperZombie/NewspaperZombieLostNewspaper", False),
    ("z_newspaper_nopaper_walk", "NewspaperZombie/NewspaperZombieNoPaper", True),
    ("z_newspaper_nopaper_attack", "NewspaperZombie/NewspaperZombieNoPaperAttack", True),
    ("z_newspaper_losthead", "NewspaperZombie/NewspaperZombieLostHead", True),
]

CARD_SIZE = (64, 89)
## 卡面主体可用区域（下部留给阳光消耗数字）
CARD_SUBJECT_RECT = (6, 5, 58, 58)
CARD_PANEL_COLOR = (180, 134, 80, 255)
CARD_BORDER_COLOR = (124, 88, 48, 255)


def load_zip_frames(sub_dir):
    """按 .._<序号>.png 顺序读出 zip 内某个动画子目录的全部帧。"""
    with zipfile.ZipFile(ZOMBIE_ZIP) as handle:
        names = [n for n in handle.namelist() if n.lower().endswith(".png")]
    target = ZOMBIE_ROOT + sub_dir
    picked = [n for n in names if os.path.dirname(n).replace("\\", "/") == target]
    if not picked:
        raise SystemExit("zip 内找不到动画目录：%s" % target)
    picked.sort(key=lambda n: int(n.rsplit("_", 1)[1][:-4]))
    with zipfile.ZipFile(ZOMBIE_ZIP) as handle:
        return [Image.open(io.BytesIO(handle.read(n))).convert("RGBA") for n in picked]


def load_gif_frames(path):
    """读 GIF 全部帧为 RGBA。"""
    image = Image.open(path)
    frames = []
    for index in range(getattr(image, "n_frames", 1)):
        image.seek(index)
        frames.append(image.convert("RGBA").copy())
    return frames


def key_white(image):
    """白底键控：把接近纯白的像素置为全透明。"""
    pixels = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a > 0 and min(r, g, b) >= WHITE_KEY_MIN:
                pixels[x, y] = (r, g, b, 0)
    return image


def content_bbox(image):
    """非透明像素的包围盒；整帧全透明时回退整幅画布。"""
    box = image.getbbox()
    if box is None:
        return (0, 0, image.size[0], image.size[1])
    return box


def union_bbox(frames):
    boxes = [content_bbox(frame) for frame in frames]
    x0 = min(box[0] for box in boxes)
    y0 = min(box[1] for box in boxes)
    x1 = max(box[2] for box in boxes)
    y1 = max(box[3] for box in boxes)
    return (x0, y0, x1, y1)


def build_pole_sheet(frames, per_frame_center):
    """重排撑杆僵尸：统一画布 + 统一脚底基线。"""
    canvas_w, canvas_h = POLE_CANVAS
    center_x = canvas_w / 2.0
    bounds = union_bbox(frames)
    base_dy = round(POLE_BASELINE - bounds[3])
    if per_frame_center:
        boxes = [content_bbox(frame) for frame in frames]
    else:
        box = bounds
        boxes = [box] * len(frames)
    out = []
    for frame, box in zip(frames, boxes):
        dx = round(center_x - (box[0] + box[2]) / 2.0)
        target = Image.new("RGBA", POLE_CANVAS, (0, 0, 0, 0))
        target.alpha_composite(frame, (dx, base_dy))
        out.append(target)
    return out


def build_newspaper_sheet(frames, white_key):
    out = []
    for frame in frames:
        if white_key:
            frame = key_white(frame)
        out.append(frame.crop(NEWSPAPER_CROP))
    return out


def save_sheet(frames, name):
    width, height = frames[0].size
    sheet = Image.new("RGBA", (width * len(frames), height), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * width, 0))
    path = os.path.join(SPRITES_DIR, name + ".png")
    sheet.save(path, optimize=True)
    print("  %-26s 帧 %2d  单帧 %dx%d" % (name + ".png", len(frames), width, height))


def rounded_panel(size):
    """卡面米色圆角底板，材质与既有 card_*.png 保持一致。"""
    panel = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(panel)
    rect = (1, 1, size[0] - 2, size[1] - 2)
    draw.rounded_rectangle(rect, radius=9, fill=CARD_PANEL_COLOR,
                           outline=CARD_BORDER_COLOR, width=2)
    return panel


def make_card(subject, out_name):
    """用植物/僵尸素体生成 64x89 卡图：米色圆角底板 + 居中缩放主体。"""
    panel = rounded_panel(CARD_SIZE)
    art = subject.crop(content_bbox(subject))
    left, top, right, bottom = CARD_SUBJECT_RECT
    max_w = right - left
    max_h = bottom - top
    scale = min(max_w / art.size[0], max_h / art.size[1])
    art_w = max(1, int(round(art.size[0] * scale)))
    art_h = max(1, int(round(art.size[1] * scale)))
    art = art.resize((art_w, art_h), Image.LANCZOS)
    panel.alpha_composite(art, (left + (max_w - art_w) // 2, top + (max_h - art_h)))
    panel.save(os.path.join(ASSETS_DIR, out_name + ".png"), optimize=True)
    print("  %-26s %dx%d" % (out_name + ".png", CARD_SIZE[0], CARD_SIZE[1]))


def build_zombies():
    if not os.path.isfile(ZOMBIE_ZIP):
        raise SystemExit("找不到原始素材压缩包：%s" % ZOMBIE_ZIP)
    print("[撑杆僵尸] 统一画布 %dx%d，脚底基线 y=%d"
          % (POLE_CANVAS[0], POLE_CANVAS[1], POLE_BASELINE))
    for name, sub_dir, per_frame in POLE_ANIMS:
        save_sheet(build_pole_sheet(load_zip_frames(sub_dir), per_frame), name)
    print("[报纸僵尸] 统一裁切 %s，白底键控阈值 %d"
          % (str(NEWSPAPER_CROP), WHITE_KEY_MIN))
    for name, sub_dir, white_key in NEWSPAPER_ANIMS:
        save_sheet(build_newspaper_sheet(load_zip_frames(sub_dir), white_key), name)
    make_card(key_white(load_zip_frames(NEWSPAPER_ANIMS[0][1])[0]), "card_newspaper")


def build_beetroot():
    idle = [key_white(frame) for frame in load_gif_frames(
        os.path.join(PREVIEW_DIR, "beetroot.gif"))]
    dying = [key_white(frame) for frame in load_gif_frames(
        os.path.join(PREVIEW_DIR, "beetroot_dying.gif"))]
    ## 待机与枯萎共用同一裁切窗口，避免状态切换时尺寸跳变
    x0 = min(union_bbox(idle)[0], union_bbox(dying)[0])
    y0 = min(union_bbox(idle)[1], union_bbox(dying)[1])
    x1 = max(union_bbox(idle)[2], union_bbox(dying)[2])
    y1 = max(union_bbox(idle)[3], union_bbox(dying)[3])
    crop = (x0, y0, x1, y1)
    print("[甜菜] 统一裁切 %s -> 主体 %dx%d" % (str(crop), x1 - x0, y1 - y0))
    save_sheet([frame.crop(crop) for frame in idle], "beetroot")
    save_sheet([frame.crop(crop) for frame in dying], "beetroot_dying")

    bullet = Image.open(os.path.join(PREVIEW_DIR, "beetbullet.png")).convert("RGBA")
    bullet.save(os.path.join(ASSETS_DIR, "beetbullet.png"), optimize=True)
    print("  %-26s %dx%d" % ("beetbullet.png", bullet.size[0], bullet.size[1]))

    make_card(Image.open(os.path.join(PREVIEW_DIR, "active_beetroot.png")).convert("RGBA"),
              "card_beetroot")
    ## 供 game_config.gd 填 dw/dh：主体像素 * 1.75
    print("  beetroot dw/dh 建议值：%.1f / %.1f"
          % ((x1 - x0) * 1.75, (y1 - y0) * 1.75))


def main():
    os.makedirs(SPRITES_DIR, exist_ok=True)
    build_zombies()
    build_beetroot()
    print("完成。请继续执行：python tools/gen_sprite_meta.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
