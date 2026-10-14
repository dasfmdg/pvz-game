"""进程内内存态存储（读写均由互斥锁保护）。

运行期可变状态：settings / progress / saves(3 个槽位)。
所有对外方法在锁内完成读写并返回深拷贝，避免调用方绕过锁改动共享状态。
"""

import copy
import logging
import threading

from . import mock_data

logger = logging.getLogger("pvz.store")

RUN_SLOT_MIN = 1
RUN_SLOT_MAX = 3
TOTAL_LEVELS = len(mock_data.LEVELS)
MAX_LEVEL_INDEX = TOTAL_LEVELS - 1


class ServerState:
    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._settings = copy.deepcopy(mock_data.DEFAULT_SETTINGS)
        self._progress = copy.deepcopy(mock_data.INITIAL_PROGRESS)
        self._saves: dict[int, dict] = {
            mock_data.INITIAL_SAVE_SLOT: {
                "saved_at": mock_data.INITIAL_SAVE_SAVED_AT,
                "snapshot": copy.deepcopy(mock_data.INITIAL_SNAPSHOT),
            }
        }

    # ---------------- 设置 ----------------
    def get_settings(self) -> dict:
        with self._lock:
            return copy.deepcopy(self._settings)

    def put_settings(self, settings: dict) -> dict:
        with self._lock:
            self._settings = copy.deepcopy(settings)
            logger.info("[设置] 已保存 bgm_volume=%s sfx_volume=%s muted=%s",
                        self._settings["bgm_volume"], self._settings["sfx_volume"],
                        self._settings["muted"])
            return copy.deepcopy(self._settings)

    # ---------------- 进度 ----------------
    def get_progress(self) -> dict:
        with self._lock:
            return copy.deepcopy(self._progress)

    def put_progress(self, progress: dict) -> dict:
        with self._lock:
            self._progress = copy.deepcopy(progress)
            logger.info("[进度] 已覆盖保存 unlocked_level=%s 记录关卡数=%s",
                        self._progress["unlocked_level"], len(self._progress["levels"]))
            return copy.deepcopy(self._progress)

    def clear_level(self, index: int, kills: int) -> tuple[int, dict]:
        """标记通关、刷新最佳击杀、解锁下一关；返回 (unlocked_level, LevelProgress)。"""
        with self._lock:
            key = str(index)
            entry = self._progress["levels"].get(key, {"cleared": False, "best_kills": 0})
            entry["cleared"] = True
            entry["best_kills"] = max(int(entry.get("best_kills", 0)), kills)
            self._progress["levels"][key] = entry
            unlocked = min(max(self._progress["unlocked_level"], index + 1), MAX_LEVEL_INDEX)
            self._progress["unlocked_level"] = unlocked
            logger.info("[通关上报] level_index=%s kills=%s -> unlocked_level=%s best_kills=%s",
                        index, kills, unlocked, entry["best_kills"])
            return unlocked, copy.deepcopy(entry)

    # ---------------- 存档（单局快照） ----------------
    def get_slot(self, slot: int) -> dict | None:
        with self._lock:
            saved = self._saves.get(slot)
            return copy.deepcopy(saved) if saved is not None else None

    def list_slots(self) -> list[dict]:
        with self._lock:
            return [self._slot_summary(slot) for slot in range(RUN_SLOT_MIN, RUN_SLOT_MAX + 1)]

    def put_slot(self, slot: int, snapshot: dict, saved_at: str) -> str:
        with self._lock:
            self._saves[slot] = {"saved_at": saved_at, "snapshot": copy.deepcopy(snapshot)}
            logger.info("[存档] 已写入 slot=%s level_index=%s saved_at=%s",
                        slot, snapshot.get("level_index"), saved_at)
            return saved_at

    def delete_slot(self, slot: int) -> bool:
        with self._lock:
            existed = self._saves.pop(slot, None) is not None
            logger.info("[存档] 删除 slot=%s existed=%s", slot, existed)
            return existed

    def latest_save(self) -> dict | None:
        """最近一次存档摘要；无存档返回 None。"""
        with self._lock:
            if not self._saves:
                return None
            slot = max(self._saves, key=lambda s: self._saves[s]["saved_at"])
            return self._slot_summary(slot)

    def _slot_summary(self, slot: int) -> dict:
        """调用方需持有锁。空槽位仅含 slot 与 empty；非空附快照摘要。"""
        saved = self._saves.get(slot)
        if saved is None:
            return {"slot": slot, "empty": True}
        snap = saved["snapshot"]
        level = mock_data.LEVELS_BY_ID.get(snap.get("level_index"))
        return {
            "slot": slot,
            "level_index": snap.get("level_index"),
            "level_name": level["name"] if level else "",
            "time": snap.get("time"),
            "sun": snap.get("sun"),
            "killed": snap.get("killed"),
            "saved_at": saved["saved_at"],
        }

    # ---------------- 概览派生 ----------------
    def overview(self) -> tuple[dict, int, int]:
        """返回 (progress 拷贝, cleared_levels, total_best_kills)。"""
        with self._lock:
            progress = copy.deepcopy(self._progress)
            cleared = sum(1 for e in progress["levels"].values() if e.get("cleared"))
            total_kills = sum(int(e.get("best_kills", 0)) for e in progress["levels"].values())
            return progress, cleared, total_kills


state = ServerState()
