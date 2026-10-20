"""概览路由（tag: 概览），主菜单聚合数据。"""

import logging

from fastapi import APIRouter

from ..errors import ok
from ..repositories import get_repository

logger = logging.getLogger("pvz.router.overview")

router = APIRouter(tags=["概览"])


@router.get("/overview", operation_id="getOverview", summary="主菜单聚合数据")
def get_overview() -> dict:
    repository = get_repository()
    progress, cleared_levels, total_best_kills = repository.overview()
    return ok({
        "unlocked_level": progress["unlocked_level"],
        "total_levels": repository.max_level_index + 1,
        "cleared_levels": cleared_levels,
        "total_best_kills": total_best_kills,
        "latest_save": repository.latest_save(),
        "settings": repository.get_settings(),
    })
