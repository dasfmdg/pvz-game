"""图鉴路由（tags: 植物图鉴 / 僵尸图鉴）。"""

import logging

from fastapi import APIRouter

from ..errors import BizError, ErrorCode, ok
from ..repositories import get_repository

logger = logging.getLogger("pvz.router.almanac")

router = APIRouter()


@router.get("/plants", tags=["植物图鉴"], operation_id="listPlants", summary="植物数值列表")
def list_plants() -> dict:
    return ok(get_repository().list_plants())


@router.get("/zombies", tags=["僵尸图鉴"], operation_id="listZombies", summary="僵尸图鉴列表")
def list_zombies() -> dict:
    return ok(get_repository().list_zombies())


@router.get("/zombies/{id}", tags=["僵尸图鉴"], operation_id="getZombie", summary="僵尸详情")
def get_zombie(id: str) -> dict:
    zombie = get_repository().get_zombie(id)
    if zombie is None:
        logger.warning("[僵尸图鉴] 未知僵尸 id=%s", id)
        raise BizError(ErrorCode.ZOMBIE_NOT_FOUND)
    return ok(zombie)
