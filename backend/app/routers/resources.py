"""资源路由（tag: 资源）。"""

import logging

from fastapi import APIRouter

from ..errors import ok
from ..repositories import get_repository

logger = logging.getLogger("pvz.router.resources")

router = APIRouter(tags=["资源"])


@router.get("/audio", operation_id="getAudio", summary="音频资源清单")
def get_audio() -> dict:
    return ok(get_repository().get_audio())


@router.get("/sprites", operation_id="getSprites", summary="精灵资源元数据清单")
def get_sprites() -> dict:
    return ok(get_repository().get_sprites())
