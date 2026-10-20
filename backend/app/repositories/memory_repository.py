"""内存态仓储：沿用原有 `store.ServerState` 与 `mock_data`，作为无数据库环境的降级/测试通道。

行为与契约对齐点：所有派生公式都从 `base.py` 取，与 MySQL 实现共用同一套算法。
"""

from __future__ import annotations

import copy

from .. import mock_data
from ..store import MAX_LEVEL_INDEX, RUN_SLOT_MAX, RUN_SLOT_MIN, state
from .base import Repository, derive_available_plants, derive_seed_slot_limit, derive_zombies_for_level


class MemoryRepository(Repository):
    @property
    def slot_min(self) -> int:
        return RUN_SLOT_MIN

    @property
    def slot_max(self) -> int:
        return RUN_SLOT_MAX

    @property
    def max_level_index(self) -> int:
        return MAX_LEVEL_INDEX

    # ---------------- 概览 ----------------
    def overview(self) -> tuple[dict, int, int]:
        return state.overview()

    # ---------------- 设置 ----------------
    def get_settings(self) -> dict:
        return state.get_settings()

    def put_settings(self, settings: dict) -> dict:
        return state.put_settings(settings)

    # ---------------- 进度 ----------------
    def get_progress(self) -> dict:
        return state.get_progress()

    def put_progress(self, progress: dict) -> dict:
        return state.put_progress(progress)

    def clear_level(self, index: int, kills: int) -> tuple[int, dict]:
        return state.clear_level(index, kills)

    # ---------------- 存档 ----------------
    def list_slots(self) -> list[dict]:
        return state.list_slots()

    def get_slot(self, slot: int) -> dict | None:
        return state.get_slot(slot)

    def put_slot(self, slot: int, snapshot: dict, saved_at: str) -> str:
        return state.put_slot(slot, snapshot, saved_at)

    def delete_slot(self, slot: int) -> bool:
        return state.delete_slot(slot)

    def latest_save(self) -> dict | None:
        return state.latest_save()

    # ---------------- 关卡元数据 ----------------
    def _rules(self) -> dict[str, int]:
        return {
            "seed_slot_base": mock_data.SEED_SLOT_BASE,
            "seed_slot_step": mock_data.SEED_SLOT_STEP,
            "seed_slot_max": mock_data.SEED_SLOT_MAX,
        }

    def _available_plants(self, index: int) -> list[str]:
        return derive_available_plants(mock_data.PLANT_ORDER, mock_data.PLANT_UNLOCK, index + 1)

    def list_levels(self) -> list[dict]:
        progress = state.get_progress()
        unlocked_level = progress["unlocked_level"]
        levels_progress = progress["levels"]
        result = []
        for level in mock_data.LEVELS:
            record = levels_progress.get(str(level["id"]), {"cleared": False, "best_kills": 0})
            result.append({
                "id": level["id"],
                "name": level["name"],
                "difficulty": level["difficulty"],
                "start_sun": level["start_sun"],
                "scene": level.get("scene", mock_data.SCENE_DAY),
                "cleared": bool(record.get("cleared", False)),
                "best_kills": int(record.get("best_kills", 0)),
                "unlocked": level["id"] <= unlocked_level,
            })
        return result

    def get_level(self, index: int) -> dict | None:
        level = mock_data.LEVELS_BY_ID.get(index)
        if level is None:
            return None
        plants = self._available_plants(index)
        return {
            "id": level["id"],
            "name": level["name"],
            "difficulty": level["difficulty"],
            "start_sun": level["start_sun"],
            "scene": level.get("scene", mock_data.SCENE_DAY),
            "waves": [copy.deepcopy(wave) for wave in level["waves"]],
            "available_plants": plants,
            "seed_slot_limit": derive_seed_slot_limit(len(plants), index + 1, self._rules()),
            "needs_seed_select": index + 1 >= mock_data.SEED_SELECT_FROM_LEVEL,
            "zombies": derive_zombies_for_level(level["waves"], set(mock_data.ZOMBIES_BY_ID)),
        }

    def get_level_plants(self, index: int) -> list[str] | None:
        if index not in mock_data.LEVELS_BY_ID:
            return None
        return self._available_plants(index)

    # ---------------- 图鉴 ----------------
    def list_plants(self) -> list[dict]:
        return [copy.deepcopy(mock_data.PLANTS_BY_ID[pid]) for pid in mock_data.PLANT_ORDER]

    def list_zombies(self) -> list[dict]:
        return copy.deepcopy(mock_data.ZOMBIES)

    def get_zombie(self, zombie_id: str) -> dict | None:
        found = mock_data.ZOMBIES_BY_ID.get(zombie_id)
        return copy.deepcopy(found) if found is not None else None

    # ---------------- 资源 ----------------
    def get_audio(self) -> dict:
        return {
            "bgm": {"name": "background", "path": mock_data.BGM_PATH},
            "sfx": copy.deepcopy(mock_data.SOUNDS),
            "pool_size": mock_data.SOUND_POOL_SIZE,
            "sfx_volume_db": mock_data.SFX_VOLUME_DB,
            "bgm_volume_db": mock_data.BGM_VOLUME_DB,
        }

    def get_sprites(self) -> dict:
        return {
            "sheets": copy.deepcopy(mock_data.SHEETS),
            "static_textures": copy.deepcopy(mock_data.STATIC_TEXTURES),
            "card_textures": copy.deepcopy(mock_data.CARD_TEXTURES),
            "card_regions": copy.deepcopy(mock_data.CARD_REGIONS),
        }
