"""图鉴路由（tags: 植物图鉴 / 僵尸图鉴）。"""

import logging

from fastapi import APIRouter

from .. import mock_data
from ..errors import BizError, ErrorCode, ok

logger = logging.getLogger("pvz.router.almanac")

router = APIRouter(tags=["植物图鉴", "僵尸图鉴"])


@router.get("/plants", operation_id="listPlants", summary="植物数值列表")
def list_plants() -> dict:
    return ok(mock_data.PLANTS)


@router.get("/zombies", operation_id="listZombies", summary="僵尸图鉴列表")
def list_zombies() -> dict:
    return ok(mock_data.ZOMBIES)


@router.get("/zombies/{zombie_id}", operation_id="getZombie", summary="僵尸详情")
def get_zombie(zombie_id: str) -> dict:
    zombie = mock_data.ZOMBIES_BY_ID.get(zombie_id)
    if zombie is None:
        logger.warning("[僵尸图鉴] 未知僵尸 id=%s", zombie_id)
        raise BizError(ErrorCode.ZOMBIE_NOT_FOUND)
    return ok(zombie)
