"""关卡路由（tag: 关卡）。

派生逻辑（可用植物 / 卡槽上限 / 是否需选卡 / 本关僵尸种类）已下沉到仓储层，
内存后端与 MySQL 后端共用 `repositories/base.py` 的同一套公式。
"""

import logging

from fastapi import APIRouter

from ..errors import BizError, ErrorCode, ok
from ..repositories import get_repository

logger = logging.getLogger("pvz.router.levels")

router = APIRouter(tags=["关卡"], prefix="/levels")


@router.get("", operation_id="listLevels", summary="关卡列表")
def list_levels() -> dict:
    return ok(get_repository().list_levels())


@router.get("/{index}", operation_id="getLevel", summary="关卡详情（含波次表）")
def get_level(index: int) -> dict:
    detail = get_repository().get_level(index)
    if detail is None:
        logger.warning("[关卡] 下标越界 level_index=%s", index)
        raise BizError(ErrorCode.LEVEL_NOT_FOUND)
    return ok(detail)


@router.get("/{index}/plants", operation_id="getLevelPlants", summary="本关可用植物")
def get_level_plants(index: int) -> dict:
    plants = get_repository().get_level_plants(index)
    if plants is None:
        logger.warning("[关卡] 下标越界 level_index=%s", index)
        raise BizError(ErrorCode.LEVEL_NOT_FOUND)
    return ok(plants)
