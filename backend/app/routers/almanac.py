"""图鉴路由（tags: 植物图鉴 / 僵尸图鉴）。"""

import logging

from fastapi import APIRouter

from .. import mock_data
from ..errors import BizError, ErrorCode, ok

logger = logging.getLogger("pvz.router.almanac")

router = APIRouter()


@router.get("/plants", tags=["植物图鉴"], operation_id="listPlants", summary="植物数值列表")
def list_plants() -> dict:
    # 按 PLANT_ORDER 输出：与 game_config.PLANT_ORDER / 图鉴界面（almanac_screen.gd）的展示顺序一致
    return ok([mock_data.PLANTS_BY_ID[plant_id] for plant_id in mock_data.PLANT_ORDER])


@router.get("/zombies", tags=["僵尸图鉴"], operation_id="listZombies", summary="僵尸图鉴列表")
def list_zombies() -> dict:
    return ok(mock_data.ZOMBIES)


@router.get("/zombies/{id}", tags=["僵尸图鉴"], operation_id="getZombie", summary="僵尸详情")
def get_zombie(id: str) -> dict:
    zombie = mock_data.ZOMBIES_BY_ID.get(id)
    if zombie is None:
        logger.warning("[僵尸图鉴] 未知僵尸 id=%s", id)
        raise BizError(ErrorCode.ZOMBIE_NOT_FOUND)
    return ok(zombie)
