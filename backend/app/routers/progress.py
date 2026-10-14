"""进度路由（tag: 进度）。"""

import logging

from fastapi import APIRouter

from ..errors import BizError, ErrorCode, ok
from ..schemas import ClearRequest, Progress
from ..store import MAX_LEVEL_INDEX, state

logger = logging.getLogger("pvz.router.progress")

router = APIRouter(tags=["进度"], prefix="/progress")


@router.get("", operation_id="getProgress", summary="获取进度")
def get_progress() -> dict:
    return ok(state.get_progress())


@router.put("", operation_id="updateProgress", summary="覆盖保存进度")
def update_progress(payload: Progress) -> dict:
    saved = state.put_progress(payload.model_dump())
    return ok(saved, "进度已保存")


@router.post("/levels/{index}/clear", operation_id="clearLevel", summary="通关上报")
def clear_level(index: int, payload: ClearRequest) -> dict:
    if index < 0 or index > MAX_LEVEL_INDEX:
        logger.warning("[通关上报] 关卡下标越界 level_index=%s", index)
        raise BizError(ErrorCode.LEVEL_NOT_FOUND)
    progress = state.get_progress()
    if index > progress["unlocked_level"]:
        logger.warning("[通关上报] 关卡未解锁 level_index=%s unlocked_level=%s",
                       index, progress["unlocked_level"])
        raise BizError(ErrorCode.LEVEL_LOCKED)
    unlocked, level = state.clear_level(index, payload.kills)
    return ok({"unlocked_level": unlocked, "level": level}, "通关已记录")
