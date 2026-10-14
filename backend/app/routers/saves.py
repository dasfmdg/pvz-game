"""存档（单局快照）路由（tag: 存档）。"""

import logging
from datetime import datetime

from fastapi import APIRouter

from ..errors import BizError, ErrorCode, ok
from ..schemas import SaveRequest
from ..store import RUN_SLOT_MAX, RUN_SLOT_MIN, state

logger = logging.getLogger("pvz.router.saves")

router = APIRouter(tags=["存档"], prefix="/saves")

SNAPSHOT_VERSION = 1


def _check_slot(slot: int) -> None:
    if slot < RUN_SLOT_MIN or slot > RUN_SLOT_MAX:
        logger.warning("[存档] 槽位越界 slot=%s", slot)
        raise BizError(ErrorCode.SLOT_INVALID)


@router.get("", operation_id="listSaves", summary="存档槽列表")
def list_saves() -> dict:
    return ok(state.list_slots())


@router.get("/{slot}", operation_id="getSaveSlot", summary="读取指定槽位快照")
def get_save_slot(slot: int) -> dict:
    _check_slot(slot)
    saved = state.get_slot(slot)
    if saved is None:
        logger.warning("[存档] 读取空槽位 slot=%s", slot)
        raise BizError(ErrorCode.SLOT_EMPTY)
    return ok({"slot": slot, "saved_at": saved["saved_at"], "snapshot": saved["snapshot"]})


@router.put("/{slot}", operation_id="upsertSaveSlot", summary="写入 / 覆盖快照")
def upsert_save_slot(slot: int, payload: SaveRequest) -> dict:
    _check_slot(slot)
    snapshot = payload.snapshot
    if snapshot.version != SNAPSHOT_VERSION:
        logger.warning("[存档] 快照版本不兼容 slot=%s version=%s", slot, snapshot.version)
        raise BizError(ErrorCode.SNAPSHOT_CONFLICT)
    saved_at = datetime.now().isoformat(timespec="seconds")
    state.put_slot(slot, snapshot.model_dump(), saved_at)
    return ok({"slot": slot}, "存档成功")


@router.delete("/{slot}", operation_id="deleteSaveSlot", summary="删除快照")
def delete_save_slot(slot: int) -> dict:
    _check_slot(slot)
    if not state.delete_slot(slot):
        logger.warning("[存档] 删除空槽位 slot=%s", slot)
        raise BizError(ErrorCode.SLOT_EMPTY)
    return ok(None, "已删除存档")
