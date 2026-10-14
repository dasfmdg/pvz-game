"""设置路由（tag: 设置）。"""

import logging

from fastapi import APIRouter

from ..errors import ok
from ..schemas import Settings
from ..store import state

logger = logging.getLogger("pvz.router.settings")

router = APIRouter(tags=["设置"])


@router.get("/settings", operation_id="getSettings", summary="获取设置")
def get_settings() -> dict:
    return ok(state.get_settings())


@router.put("/settings", operation_id="updateSettings", summary="保存设置")
def update_settings(payload: Settings) -> dict:
    saved = state.put_settings(payload.model_dump())
    return ok(saved, "设置已保存")
