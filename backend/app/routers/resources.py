"""资源路由（tag: 资源）。"""

import logging

from fastapi import APIRouter

from .. import mock_data
from ..errors import ok

logger = logging.getLogger("pvz.router.resources")

router = APIRouter(tags=["资源"])


@router.get("/audio", operation_id="getAudio", summary="音频资源清单")
def get_audio() -> dict:
    return ok({
        "bgm": {"name": "background", "path": mock_data.BGM_PATH},
        "sfx": mock_data.SOUNDS,
        "pool_size": mock_data.SOUND_POOL_SIZE,
        "sfx_volume_db": mock_data.SFX_VOLUME_DB,
        "bgm_volume_db": mock_data.BGM_VOLUME_DB,
    })


@router.get("/sprites", operation_id="getSprites", summary="精灵资源元数据清单")
def get_sprites() -> dict:
    return ok({
        "sheets": mock_data.SHEETS,
        "static_textures": mock_data.STATIC_TEXTURES,
        "card_textures": mock_data.CARD_TEXTURES,
        "card_regions": mock_data.CARD_REGIONS,
    })
