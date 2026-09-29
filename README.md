# pvz-game（Godot 4.6 版植物大战僵尸）

基于 **Godot 4.6 + GDScript** 重写的植物大战僵尸网页/桌面可玩版本，玩法与数值对齐 `../pvzcode`（网页版）的
`js/config.js`，工程结构参考 `../PVZ-Godot-Dream-main`（autoload 事件总线 + 管理器 + 实体分层）。

## 运行方式

```bash
# 编辑器打开
godot --path . -e

# 直接运行（窗口 / 全屏 1920×1080）
godot --path .

# 命令行冒烟校验（无窗口，跑 400 帧后退出）
godot --headless --path . --quit-after 400
```

渲染后端为 **GL Compatibility**，可在低配机器与网页导出下运行。项目入口场景为 `scenes/main.tscn`，
世界与 UI 节点全部由代码构建，`.tscn` 仅保留一个挂载 `scripts/main.gd` 的根节点。

## 操作

| 输入 | 行为 |
| --- | --- |
| 鼠标左键 | 收集阳光 / 放置已选中的植物 / 铲除（铲子模式） |
| 数字键 1~9、0 | 选择卡片槽中的第 1~10 张卡片 |
| Esc | 取消当前手持（卡片 / 铲子） |
| P | 暂停 / 继续 |
| M | 静音 / 恢复 |
| R | 结束后重开一局 |

## 玩法内容

- **植物 11 种**：向日葵、豌豆射手、坚果墙、樱桃炸弹、双发射手、火爆辣椒、寒冰射手、三重射手、倭瓜、食人花、土豆地雷。
- **僵尸 6 种**：普通、路障、铁桶、橄榄球、铁门、旗帜；支持顶具护甲分段扣血、顶具剥离外观切换、
  残血失头/断臂破损外观、寒冰减速染色、烧焦动画。
- **30 关关卡**（数据对齐 `../pvzcode/js/levels-data.js`，逐关逐波一致）：每关 3~9 波，含 `huge` 大波
  （自动追加旗帜僵尸与横幅提示），难度 1~8，初始阳光 50/75/100；5 行 × 9 列草坪，每行一台一次性小推车。
- 卡片每关全量开放 11 种植物（源数据的 `unlockLevel` 逐关解锁未接入）。
- 阳光经济：开局 50，天降阳光每 10 秒一颗，向日葵每 12 秒产出一颗。

## 目录结构

```
scenes/main.tscn            入口场景（仅根节点，其余节点代码构建）
scripts/main.gd             启动入口：界面路由（主菜单 → 关卡选择 / 图鉴 / 设置 → 关卡）
scripts/autoload/           EventBus / GameConfig / SpriteLibrary / SoundManager / SaveManager 五个单例
scripts/data/sprite_meta.gd 精灵表帧元数据（由 tools/gen_sprite_meta.py 生成，勿手改）
scripts/entities/           植物基类与 7 类植物、僵尸基类、豌豆、阳光、小推车、特效
scripts/managers/           主控、格子与种植、阳光经济、波次调度、小推车管理
scripts/screens/            主菜单、关卡选择（30 关滚动网格）、图鉴、设置与界面公共工具 UiKit
scripts/ui/                 卡片槽与冷却、HUD、横幅、胜负遮罩
assets/                     精灵表 PNG、WAV 音效、卡片图、草坪背景（来自 ../pvzcode/assets）
tools/gen_sprite_meta.py    从 ../pvzcode/js/sprites-meta.js 生成 scripts/data/sprite_meta.gd
tools/headless_sim.*        无窗口整局模拟（自动采集阳光 + 布阵，验证波次/胜负链路）
tools/entity_test.*         无窗口实体层单元校验（87 项断言：顶具/破损/减速/各类植物行为）
tools/screen_test.*         无窗口界面层校验（116 项断言：路由、存档、30 关数据、图鉴、设置）
```

## 校验与测试

```bash
# 资源导入（首次或新增素材后执行）
godot --headless --path . --import

# 整局模拟：固定 60fps 推进 500 秒游戏时间，输出波次/击杀/破防/胜负日志
godot --headless --fixed-fps 60 --quit-after 30000 --path . res://tools/headless_sim.tscn

# 实体层单测：输出 PASS/FAIL 断言清单
godot --headless --fixed-fps 60 --quit-after 2400 --path . res://tools/entity_test.tscn
```

## 数值调整

所有数值集中在 `scripts/autoload/game_config.gd`：棋盘坐标、阳光经济、植物价格/生命/冷却、
僵尸生命/速度/顶具、波次时间表、小推车与弹道参数。调整数值只改这一个文件。

## 素材

素材来源为 `../pvzcode/assets`，精灵表为横向排列的逐帧 PNG。帧数与帧时长元数据由
`tools/gen_sprite_meta.py` 从 `../pvzcode/js/sprites-meta.js` 解析生成，并会用 PNG 实际宽度校验帧数：

```bash
python tools/gen_sprite_meta.py ../pvzcode/js/sprites-meta.js scripts/data/sprite_meta.gd
```

> 注意：`assets/card_pole.png` 原文件实为 JPEG，已在 Godot 工程中改名为 `card_pole.jpg` 以便引擎导入。

## 待办

- 夜景表现：源数据第 16/21/24/26/28/30 关为 `scene: night`，当前未做夜色背景与阳光产出限制。
- 植物逐关解锁：源数据 `unlockLevel`（坚果 3 / 土豆雷 4 / 樱桃 5 / 双发 7 / 辣椒 9 / 寒冰 11 /
  倭瓜 13 / 食人花 15 / 三重 17）未接入，当前每关全量开放。
- 关卡立绘仅 1~5 关（`assets/ui/level1~5.png`），其余关卡在关卡选择页用编号底板兜底。
- 30 关未逐关人工通关，目前只做了逐关数据校验（`tools/screen_test.gd`）与第 1 关整局模拟。