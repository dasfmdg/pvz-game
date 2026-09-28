extends Node
## 全局事件总线（参考 PVZ-Godot-Dream-main 的 EventBus 模式）
## 约定：信号只做“通知”，不承载可变业务状态，避免模块之间直接耦合。

# ---------------- 阳光经济 ----------------
signal sun_changed(value: int)
signal sun_collected(value: int)

# ---------------- 卡片与手持状态 ----------------
signal card_selected(plant_id: String)
signal card_selection_cleared()
signal shovel_selected()
signal card_used(plant_id: String)

# ---------------- 种植 ----------------
signal plant_placed(plant_id: String, cell: Vector2i)
signal plant_removed(cell: Vector2i)

# ---------------- 僵尸与波次 ----------------
signal zombie_died(lane: int, is_burnt: bool)
signal zombie_breached(lane: int)
signal wave_started(wave_index: int, total_waves: int, is_huge: bool)
signal all_waves_spawned()

# ---------------- 进程 ----------------
signal game_over(is_win: bool, killed: int)
signal game_paused(is_paused: bool)
signal sound_muted(is_muted: bool)