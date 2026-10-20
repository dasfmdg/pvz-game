"""设置路由（tag: 设置）。"""

import logging

from fastapi import APIRouter

from ..errors import ok
from ..repositories import get_repository
from ..schemas import Settings

logger = logging.getLogger("pvz.router.settings")

router = APIRouter(tags=["设置"])


@router.get("/settings", operation_id="getSettings", summary="获取设置")
def get_settings() -> dict:
    return ok(get_repository().get_settings())


@router.put("/settings", operation_id="updateSettings", summary="保存设置")
def update_settings(payload: Settings) -> dict:
    return ok(get_repository().put_settings(payload.model_dump()), "设置已保存")
