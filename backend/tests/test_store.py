"""单元测试：进程内状态机 ServerState（设置 / 进度 / 存档 / 概览派生）。"""

import copy

from app import mock_data
from app.store import (
    MAX_LEVEL_INDEX,
    RUN_SLOT_MAX,
    RUN_SLOT_MIN,
    TOTAL_LEVELS,
    ServerState,
)


def test_global_constants_match_contract():
    assert TOTAL_LEVELS == 40
    assert MAX_LEVEL_INDEX == 39
    assert (RUN_SLOT_MIN, RUN_SLOT_MAX) == (1, 3)


# ---------------- 设置 ----------------
def test_default_settings():
    state = ServerState()
    assert state.get_settings() == {"bgm_volume": 0.8, "sfx_volume": 1.0, "muted": False}


def test_put_settings_replaces_whole_partition():
    state = ServerState()
    new = {"bgm_volume": 0.0, "sfx_volume": 0.5, "muted": True}
    assert state.put_settings(new) == new
    assert state.get_settings() == new


def test_get_settings_returns_deep_copy():
    state = ServerState()
    state.get_settings()["muted"] = True
    assert state.get_settings()["muted"] is False


# ---------------- 进度 ----------------
def test_initial_progress_matches_contract_example():
    state = ServerState()
    assert state.get_progress() == mock_data.INITIAL_PROGRESS


def test_put_progress_replaces_whole_partition():
    state = ServerState()
    new = {"unlocked_level": 5, "levels": {"5": {"cleared": False, "best_kills": 3}}}
    assert state.put_progress(new) == new
    assert state.get_progress() == new


def test_clear_level_marks_cleared_and_unlocks_next():
    state = ServerState()
    unlocked, level = state.clear_level(2, 18)
    assert unlocked == 3
    assert level == {"cleared": True, "best_kills": 18}
    assert state.get_progress()["levels"]["2"] == {"cleared": True, "best_kills": 18}
    assert state.get_progress()["unlocked_level"] == 3


def test_clear_level_keeps_historical_best_kills():
    state = ServerState()
    # 关卡 0 初始 best_kills = 18，低于历史值的上报不应拉低记录
    _, level = state.clear_level(0, 5)
    assert level["best_kills"] == 18
    # 高于历史值则刷新
    _, level = state.clear_level(0, 99)
    assert level["best_kills"] == 99


def test_clear_level_caps_unlock_at_last_index():
    state = ServerState()
    state.put_progress({"unlocked_level": 39, "levels": {}})
    unlocked, _ = state.clear_level(39, 1)
    assert unlocked == MAX_LEVEL_INDEX


# ---------------- 存档 ----------------
def test_list_slots_shape():
    state = ServerState()
    slots = state.list_slots()
    assert [item["slot"] for item in slots] == [1, 2, 3]
    assert slots[0]["level_index"] == 2
    assert slots[0]["level_name"] == "第3关 · 铁桶初现"
    assert slots[1] == {"slot": 2, "empty": True}
    assert slots[2] == {"slot": 3, "empty": True}


def test_get_slot_of_empty_returns_none():
    state = ServerState()
    assert state.get_slot(2) is None


def test_put_get_delete_slot_roundtrip():
    state = ServerState()
    assert state.put_slot(2, copy.deepcopy(mock_data.INITIAL_SNAPSHOT), "2026-10-11T00:00:00") == "2026-10-11T00:00:00"
    saved = state.get_slot(2)
    assert saved["saved_at"] == "2026-10-11T00:00:00"
    assert saved["snapshot"]["level_index"] == 2
    assert state.delete_slot(2) is True
    assert state.delete_slot(2) is False


def test_get_slot_returns_deep_copy():
    state = ServerState()
    state.get_slot(1)["snapshot"]["sun"] = 0
    assert state.get_slot(1)["snapshot"]["sun"] == 275


def test_latest_save_picks_most_recent():
    state = ServerState()
    state.put_slot(1, copy.deepcopy(mock_data.INITIAL_SNAPSHOT), "2026-10-10T20:15:30")
    state.put_slot(2, copy.deepcopy(mock_data.INITIAL_SNAPSHOT), "2026-10-12T09:00:00")
    assert state.latest_save()["slot"] == 2


def test_latest_save_none_when_all_empty():
    state = ServerState()
    for slot in (RUN_SLOT_MIN, RUN_SLOT_MAX):
        state.delete_slot(slot)
    assert state.latest_save() is None


# ---------------- 概览派生 ----------------
def test_overview_aggregates_counts():
    state = ServerState()
    progress, cleared, total_kills = state.overview()
    assert progress["unlocked_level"] == 2
    assert cleared == 2
    assert total_kills == 42
