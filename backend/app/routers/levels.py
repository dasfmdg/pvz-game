"""关卡路由（tag: 关卡）。"""

import logging

from fastapi import APIRouter

from .. import mock_data
from ..errors import BizError, ErrorCode, ok
from ..store import MAX_LEVEL_INDEX, state

logger = logging.getLogger("pvz.router.levels")

router = APIRouter(tags=["关卡"], prefix="/levels")


def _check_index(index: int) -> None:
    if index < 0 or index > MAX_LEVEL_INDEX:
        logger.warning("[关卡] 下标越界 level_index=%s", index)
        raise BizError(ErrorCode.LEVEL_NOT_FOUND)


def plants_for_level(level_id: int) -> list[str]:
    """level_id 为 1 基：PLANT_UNLOCK 中 unlock_level <= level_id 的植物全部开放。"""
    return [pid for pid in mock_data.PLANT_ORDER
            if mock_data.PLANT_UNLOCK.get(pid, 0) <= level_id]


def _seed_slot_limit(level_id: int) -> int:
    unlocked = len(plants_for_level(level_id))
    grown = mock_data.SEED_SLOT_BASE + max(level_id - 1, 0) // mock_data.SEED_SLOT_STEP
    return max(1, min(unlocked, min(grown, mock_data.SEED_SLOT_MAX), mock_data.SEED_SLOT_MAX))


def _zombies_for_level(index: int) -> list[str]:
    """本关出现的僵尸类型，按首次出现顺序去重，不含大波自动追加的 flag。"""
    level = mock_data.LEVELS_BY_ID.get(index, {})
    result: list[str] = []
    for wave in level.get("waves", []):
        for zid in wave.get("z", []):
            if zid == "flag" or zid not in mock_data.ZOMBIES_BY_ID or zid in result:
                continue
            result.append(zid)
    return result


@router.get("", operation_id="listLevels", summary="关卡列表")
def list_levels() -> dict:
    progress = state.get_progress()
    unlocked_level = progress["unlocked_level"]
    levels_progress = progress["levels"]
    data = []
    for level in mock_data.LEVELS:
        rec = levels_progress.get(str(level["id"]), {"cleared": False, "best_kills": 0})
        data.append({
            "id": level["id"],
            "name": level["name"],
            "difficulty": level["difficulty"],
            "start_sun": level["start_sun"],
            "scene": level.get("scene", mock_data.SCENE_DAY),
            "cleared": bool(rec.get("cleared", False)),
            "best_kills": int(rec.get("best_kills", 0)),
            "unlocked": level["id"] <= unlocked_level,
        })
    return ok(data)


@router.get("/{index}", operation_id="getLevel", summary="关卡详情（含波次表）")
def get_level(index: int) -> dict:
    _check_index(index)
    level = mock_data.LEVELS_BY_ID[index]
    return ok({
        "id": level["id"],
        "name": level["name"],
        "difficulty": level["difficulty"],
        "start_sun": level["start_sun"],
        "scene": level.get("scene", mock_data.SCENE_DAY),
        "waves": level["waves"],
        "available_plants": plants_for_level(index + 1),
        "seed_slot_limit": _seed_slot_limit(index + 1),
        "needs_seed_select": index + 1 >= mock_data.SEED_SELECT_FROM_LEVEL,
        "zombies": _zombies_for_level(index),
    })


@router.get("/{index}/plants", operation_id="getLevelPlants", summary="本关可用植物")
def get_level_plants(index: int) -> dict:
    _check_index(index)
    return ok(plants_for_level(index + 1))
