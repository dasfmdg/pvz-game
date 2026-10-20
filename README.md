# pvz-game（Godot 4.6 版植物大战僵尸）

> [!IMPORTANT]
> **版权声明：本项目仅用于学习目的，未经授权请勿用于商业用途。**
> 本项目为个人学习与技术研究项目，禁止任何形式的商业使用（销售、付费分发、广告变现、内购、商业运营等）。
> 项目内《植物大战僵尸》的美术素材、音效与角色形象，版权归 PopCap Games, Inc. / Electronic Arts Inc. 及其关联方所有。
> 完整条款见 [LICENSE](LICENSE)。

基于 **Godot 4.6 + GDScript** 重写的植物大战僵尸网页/桌面可玩版本：基础玩法与数值对齐 `../pvzcode`（网页版）的
`js/config.js`（该表为 11 植物 / 6 僵尸），本工程在其上新增了西瓜投手、甜菜、撑杆僵尸与读报僵尸；工程结构参考
`../PVZ-Godot-Dream-main`（autoload 事件总线 + 管理器 + 实体分层）。

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
| 鼠标左键 / 任意按键 | 启动加载页：进入主菜单 |
| 鼠标左键 | 收集阳光 / 放置已选中的植物 / 铲除（铲子模式） |
| 数字键 1~9、0 | 选择卡片槽中的第 1~10 张卡片 |
| Esc | 取消当前手持（卡片 / 铲子） |
| P | 暂停 / 继续 |
| M | 静音 / 恢复 |
| R | 结束后重开一局 |

## 玩法内容

- **植物 13 种**：向日葵、豌豆射手、坚果墙、樱桃炸弹、双发射手、火爆辣椒、寒冰射手、三重射手、倭瓜、食人花、土豆地雷、西瓜投手、甜菜。
- **僵尸 8 种**：普通、路障、铁桶、橄榄球、铁门、旗帜、撑杆、读报；支持顶具护甲分段扣血、顶具剥离外观切换、
  残血失头/断臂破损外观、寒冰减速染色、烧焦动画。
- **40 关关卡**（前 30 关波次对齐 `../pvzcode/js/levels-data.js`，后 10 关为本工程后日谈扩展）：每关 3~9 波，
  含 `huge` 大波（自动追加旗帜僵尸与横幅提示），难度 1~10，初始阳光 50/75/100；5 行 × 9 列草坪，
  每行一台一次性小推车。
- **植物逐关解锁**：按源数据 `unlockLevel`（坚果 3 / 土豆雷 4 / 樱桃 5 / 双发 7 / 辣椒 9 / 寒冰 11 /
  倭瓜 13 / 食人花 15 / 三重 17 / 西瓜投手 17 / 甜菜 21）生成每关卡片，第 1 关仅向日葵与豌豆射手，
  第 21 关起全量 13 种。
- **夜景关卡 10 关**（第 16/21/24/26/28/30/33/35/38/40 关，源数据 `scene: night`）：草坪转为夜色冷色调，
  且不再天降阳光，只能靠向日葵产阳光。
- **选卡界面**（第 7 关起）：进关前先选携带的植物，界面上方列出本关会出现的僵尸种类（中文名 + 立绘），
  下方从已解锁植物里点选/取消，选卡顺序即时显示；槽位上限 `min(已解锁数, 5 + 每 4 关 +1, 10)`，
  即第 7 关 6 张、第 11 关 7 张、第 17 关 9 张、第 21 关起封顶 10 张；第 1~6 关仍直接进关。
  选卡结果只存在本次运行内存里，结算后按 `R` 重试沿用同一套卡片，退出游戏不落存档。
- 阳光经济：初始阳光按关卡配置 50 / 75 / 100，天降阳光每 10 秒一颗（夜间不下），向日葵每 12 秒产出一颗。

## 目录结构

```
scenes/main.tscn            入口场景（仅根节点，其余节点代码构建）
scripts/main.gd             启动入口：界面路由（启动加载页 → 主菜单 → 关卡选择 / 图鉴 / 设置 → 选卡 → 关卡）
scripts/autoload/           EventBus / GameConfig / SpriteLibrary / SoundManager / SaveManager 五个单例
scripts/data/sprite_meta.gd 精灵表帧元数据（由 tools/gen_sprite_meta.py 生成，勿手改）
scripts/entities/           植物基类与 9 类植物、僵尸基类与 2 类特殊僵尸、植物 / 僵尸工厂、豌豆 / 甜菜 / 西瓜弹、阳光、小推车、特效
scripts/managers/           主控、格子与种植、阳光经济、波次调度、小推车管理
scripts/screens/            启动加载页、主菜单、关卡选择（40 关滚动网格）、选卡、图鉴、设置与界面公共工具 UiKit
scripts/ui/                 卡片槽与冷却、HUD、横幅、胜负遮罩、选卡界面用的卡片控件
assets/                     精灵表 PNG、WAV 音效、卡片图、草坪背景（来自 ../pvzcode/assets）
tools/gen_sprite_meta.py    从 ../pvzcode/js/sprites-meta.js 生成 scripts/data/sprite_meta.gd
tools/headless_sim.*        无窗口整局模拟（自动采集阳光 + 布阵，验证波次/胜负链路）
tools/entity_test.*         无窗口实体层单元校验（顶具/破损/减速/各类植物与僵尸行为，运行时打印 PASS/FAIL 清单）
tools/screen_test.*         无窗口界面层校验（路由、选卡、存档、40 关数据与解锁表、图鉴、设置，运行时打印 PASS/FAIL 清单）
tools/level_sim.*           无窗口 40 关逐关模拟（逐关自动布阵打到结束，验证波次/胜负链路不卡死）
openapi.yaml                后端接口契约（OpenAPI 3.0.3，14 path / 18 operation / 27 schema）
pvz_game.dbml               数据库物理结构（DBML，目标 MySQL 8.0，28 表 / 29 外键）
pvz_game.json               同上的 drawDB 兼容 JSON（可导入 drawDB 可视化）
backend/db/                 数据库接入层（DBML→DDL 生成器、schema.sql、连接与 seed）
backend/app/repositories/   仓储层（base 接口 + mysql 实现 + memory 降级实现）
backend/scripts/            本地 MySQL 实例管理与一键初始化（mysql_local.ps1 / db_up.py）
backend/                    FastAPI 服务（按 openapi.yaml 逐接口实现，默认持久化到 MySQL）
backend/tests/              后端测试（pytest：单元 / 集成 / 契约一致性 / MySQL 专项 / schema 一致性，170 项）
web/                        Web 前端对接层（Vite + TypeScript：契约类型 + 请求封装 + 7 个视图）
```

## 后端接口与数据库结构

本工程为纯离线单机游戏，源码内不含任何 HTTP 调用。另附一套「后端服务 + 数据库物理结构」，供联调、归档与演示使用：

- **接口契约**：[openapi.yaml](openapi.yaml)（OpenAPI 3.0.3，14 path / 18 operation / 27 schema）。统一响应体 `{ "code": 0, "msg": "ok", "data": ... }`，无登录鉴权（进度按单机玩家维度处理）；关卡下标 **0 基**、存档槽位 **1~3**、字段名全部 snake_case。
- **后端服务**：`backend/`（FastAPI + uvicorn，端点统一挂 `/api` 前缀）。**默认持久化到真实 MySQL 8.0**；设 `PVZ_STORE=memory` 可切回纯内存态（无数据库环境下的降级 / 测试通道），两种后端共用同一套派生公式与契约断言。
- **数据库物理结构**：[pvz_game.dbml](pvz_game.dbml)（DBML，目标 MySQL 8.0，28 张表 / 29 条外键）与 [pvz_game.json](pvz_game.json)（同内容的 drawDB 兼容 JSON，可导入 drawDB 可视化）。按模块划分：玩家与设置、进度、存档快照、关卡配置、植物图鉴、僵尸图鉴、资源（音频 / 精灵）、全局规则与错误码、对局事件与运营指标。该结构已是**运行库**：由 `backend/db/generate_schema.py` 编译成幂等的 `backend/db/schema.sql`，服务启动时反射使用。
- **单一事实来源链**：`pvz_game.dbml` → `backend/db/schema.sql` → 真实 MySQL → SQLAlchemy 反射。代码里不存在第二份表结构定义；`backend/tests/test_schema_parity.py` 锁死这条链（改了 DBML 却忘记重新生成 DDL 会直接测试失败）。
- **Web 前端对接层**：`web/`（Vite + TypeScript，`strict`）。含与契约 27 个 schema 同源的类型定义（字段保持 snake_case）、统一 `{ "code", "msg", "data" }` 解包与错误码抛出的请求封装，以及与 18 个 operation 一一对应的调用函数与 7 个视图（概览 / 设置 / 进度 / 存档 / 关卡 / 图鉴 / 资源，每个异步视图均含 Loading / Error / Empty 三态）。

```bash
# 1) 启动本地 MySQL（便携实例：独立 datadir + 端口 3307，不动系统服务与其它项目的 data 目录）
powershell -File backend/scripts/mysql_local.ps1 start

# 2) 建库 + 应用 schema + 灌初始数据（幂等，可重复执行；不会覆盖玩家已有进度与存档）
python backend/scripts/db_up.py

# 3) 启动服务（默认 PVZ_STORE=mysql，连 127.0.0.1:3307；用 PVZ_STORE=memory 可切内存态）
cd backend
pip install -r requirements.txt
uvicorn app.main:app --port 3000
# 交互式接口文档：http://localhost:3000/docs
```

> 连接串可用 `PVZ_DB_DSN` 覆盖（默认 `mysql+pymysql://root@127.0.0.1:3307/pvz_game`）；便携实例的安装目录与端口可用 `PVZ_MYSQL_BASE` / `PVZ_MYSQL_PORT` 覆盖。

> 数据来源为工程真实数据模型（`save_manager.gd` / `game_config.gd` / `sound_manager.gd` / `sprite_library.gd` / `sprite_meta.gd`）；工程契约未定义订阅 / 交易 / 获客等商业数据源，故未建对应表。

## 校验与测试

```bash
# 资源导入（首次或新增素材后执行）
godot --headless --path . --import

# 整局模拟：固定 60fps 推进 500 秒游戏时间，输出波次/击杀/破防/胜负日志
godot --headless --fixed-fps 60 --quit-after 30000 --path . res://tools/headless_sim.tscn

# 实体层单测：输出 PASS/FAIL 断言清单
godot --headless --fixed-fps 60 --quit-after 2400 --path . res://tools/entity_test.tscn

# 40 关逐关模拟：逐关装载关卡数据、自动布阵打到结束，输出每关胜负与异常项
godot --headless --fixed-fps 60 --path . res://tools/level_sim.tscn
```

### 后端（Mock 服务）测试

```bash
cd backend
pip install -r requirements-dev.txt   # pytest + httpx + PyYAML
pytest                                # 170 项：单元 / 集成 / 契约一致性 / MySQL 专项 / schema 一致性
```

测试分层：`tests/test_store.py`、`tests/test_schemas.py`、`tests/test_levels_logic.py` 为单元测试；
`tests/test_api_*.py` 用 FastAPI TestClient 覆盖 18 个 operation 的正常 / 边界 / 异常场景；
`tests/test_contract.py` 解析 `openapi.yaml` 并与应用自生成 OpenAPI 逐条比对，确保 path / method /
operationId / 响应结构零偏差。

测试默认跑**内存后端**，因此没有数据库也能完整验证契约；另外两套用例在 MySQL 可用时会自动执行
（不可用则 `skip`，不会把"没跑"说成"通过"）：`tests/test_repository_mysql.py` 验证真库行为、
存档全图往返与"重启后数据仍在"，`tests/test_schema_parity.py` 锁死 DBML ↔ schema.sql ↔ 真实库的一致性。

```bash
# 数据库结构三链一致性（无需数据库）
python backend/db/generate_schema.py --check
```

### Web 前端对接层

```bash
cd web
npm install
npm run dev       # 开发服务 http://localhost:5173
npm run build     # tsc --noEmit + vite build
npm run preview   # 预览构建产物 http://localhost:4173
```

接口基址默认为契约 `servers[0]`（`http://localhost:3000/api`），可用环境变量 `VITE_API_BASE` 覆盖。

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

## 版权与使用限制

- **本项目仅用于学习目的，未经授权请勿用于商业用途。**
- 允许：个人学习、技术研究、教学演示等非商业目的下的下载、阅读、编译、运行与修改。
- 禁止：任何商业用途（销售、付费分发、广告变现、内购、商业运营，及基于本项目提供的付费服务或培训）。
- 禁止：删除或篡改 `LICENSE` 与源代码中的版权标识；再分发时必须保留本声明并同样限定为非商业用途。
- 素材与商标：项目内《植物大战僵尸》的美术素材（植物、僵尸、卡片、草坪背景、界面图片等）、音效，
  以及 "Plants vs. Zombies / 植物大战僵尸" 名称与角色形象，版权与商标权归
  PopCap Games, Inc. / Electronic Arts Inc. 及其关联方所有；本项目仅在非商业学习与演示场景下引用，
  不主张任何权利，非官方作品，亦未获权利人授权。用于公开或商业场景请自行取得授权。
- 免责：本项目按 "现状" 提供，不附带任何担保，使用产生的损失作者不承担责任。

完整条款见仓库根目录 [LICENSE](LICENSE)。

## 待办

- 关卡立绘仅 1~5 关（`assets/ui/level1~5.png`），其余关卡在关卡选择页用编号底板兜底。
- 40 关未逐关人工通关：已用 `tools/level_sim.gd` 做逐关自动布阵模拟（覆盖全部关卡），
  但自动模拟不等于真人可通关性验证。
- 夜景目前只做了草坪冷色调，未加月亮/路灯等美术元素。这块**等美术素材再动**：`assets/lawn.png`
  是俯视后院草坪，上方是白色围栏、左侧是房屋屋顶，没有天空区，月亮无处安放，因此不做程序化模拟。
  需要的素材是 `assets/lawn_night.png`（1920×1080 PNG，与 `assets/lawn.png` 同构图，草坪网格区
  x 606~1911 / y 178~1023 保持干净以免干扰辨识）。**接线已完成**：`game_config.gd` 已定义
  `NIGHT_LAWN_PATH`，`main_game_manager.gd` 的夜间关卡会优先加载该素材，文件缺失时自动回退到
  `lawn.png + NIGHT_LAWN_TINT`（不阻断游戏）。因此**只需把 `assets/lawn_night.png` 放进目录**，
  夜景立绘即刻生效，无需再改代码。