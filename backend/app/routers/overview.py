"""概览路由（tag: 概览），主菜单聚合数据。"""

import logging

from fastapi import APIRouter

from ..errors import ok
from ..store import TOTAL_LEVELS, state

logger = logging.getLogger("pvz.router.overview")

router = APIRouter(tags=["概览"])


@router.get("/overview", operation_id="getOverview", summary="主菜单聚合数据")
def get_overview() -> dict:
    progress, cleared_levels, total_best_kills = state.overview()
    return ok({
        "unlocked_level": progress["unlocked_level"],
        "total_levels": TOTAL_LEVELS,
        "cleared_levels": cleared_levels,
        "total_best_kills": total_best_kills,
        "latest_save": state.latest_save(),
        "settings": state.get_settings(),
    })
