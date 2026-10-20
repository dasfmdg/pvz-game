"""仓储层公共约定：接口定义 + 与后端无关的派生公式。

设计意图：
- 路由层只依赖 `Repository` 接口，不关心数据来自内存还是 MySQL；
- 关卡派生逻辑（可用植物 / 卡槽上限 / 本关僵尸种类）在两个后端之间**共用同一套公式**，
  避免「内存态与真库行为不一致」这类隐蔽偏差。
"""

from __future__ import annotations

from abc import ABC, abstractmethod


class Repository(ABC):
    """后端存储接口：覆盖 openapi.yaml 全部 18 个 operation 所需的数据访问。"""

    # ---------------- 边界常量（来源：game_rules / 内存常量） ----------------
    @property
    @abstractmethod
    def slot_min(self) -> int: ...

    @property
    @abstractmethod
    def slot_max(self) -> int: ...

    @property
    @abstractmethod
    def max_level_index(self) -> int: ...

    # ---------------- 概览 ----------------
    @abstractmethod
    def overview(self) -> tuple[dict, int, int]:
        """返回 (progress, cleared_levels, total_best_kills)。"""

    # ---------------- 设置 ----------------
    @abstractmethod
    def get_settings(self) -> dict: ...

    @abstractmethod
    def put_settings(self, settings: dict) -> dict: ...

    # ---------------- 进度 ----------------
    @abstractmethod
    def get_progress(self) -> dict: ...

    @abstractmethod
    def put_progress(self, progress: dict) -> dict: ...

    @abstractmethod
    def clear_level(self, index: int, kills: int) -> tuple[int, dict]:
        """标记通关并解锁下一关，返回 (unlocked_level, LevelProgress)。"""

    # ---------------- 存档（单局快照） ----------------
    @abstractmethod
    def list_slots(self) -> list[dict]: ...

    @abstractmethod
    def get_slot(self, slot: int) -> dict | None:
        """返回 {"saved_at": str, "snapshot": dict}；空槽位返回 None。"""

    @abstractmethod
    def put_slot(self, slot: int, snapshot: dict, saved_at: str) -> str: ...

    @abstractmethod
    def delete_slot(self, slot: int) -> bool: ...

    @abstractmethod
    def latest_save(self) -> dict | None: ...

    # ---------------- 关卡元数据 ----------------
    @abstractmethod
    def list_levels(self) -> list[dict]: ...

    @abstractmethod
    def get_level(self, index: int) -> dict | None: ...

    @abstractmethod
    def get_level_plants(self, index: int) -> list[str] | None: ...

    # ---------------- 图鉴 ----------------
    @abstractmethod
    def list_plants(self) -> list[dict]: ...

    @abstractmethod
    def list_zombies(self) -> list[dict]: ...

    @abstractmethod
    def get_zombie(self, zombie_id: str) -> dict | None: ...

    # ---------------- 资源 ----------------
    @abstractmethod
    def get_audio(self) -> dict: ...

    @abstractmethod
    def get_sprites(self) -> dict: ...


# ---------------------------------------------------------------------------
# 派生公式（与 game_config.gd 的同名函数语义一致）
# ---------------------------------------------------------------------------
def derive_available_plants(order: list[str], unlock_by_id: dict[str, int], level_id: int) -> list[str]:
    """plants_for_level：unlock_level <= level_id 的植物，按 PLANT_ORDER 输出。"""
    return [plant_id for plant_id in order if unlock_by_id.get(plant_id, 0) <= level_id]


def derive_seed_slot_limit(unlocked_count: int, level_id: int, rules: dict) -> int:
    """seed_slot_limit：clampi(min(unlocked, min(grown, MAX)), 1, MAX)。"""
    grown = rules["seed_slot_base"] + max(level_id - 1, 0) // rules["seed_slot_step"]
    value = min(unlocked_count, min(grown, rules["seed_slot_max"]))
    return max(1, min(value, rules["seed_slot_max"]))


def derive_zombies_for_level(waves: list[dict], known_ids: set[str]) -> list[str]:
    """zombies_for_level：按首次出现顺序去重，不含大波自动追加的 flag。"""
    result: list[str] = []
    for wave in waves:
        for zombie_id in wave.get("z", []):
            if zombie_id == "flag" or zombie_id not in known_ids or zombie_id in result:
                continue
            result.append(zombie_id)
    return result
