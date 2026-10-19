"""单元测试：Pydantic 请求模型与契约字段约束（正常 / 边界 / 非法）。"""

import copy

import pytest
from pydantic import ValidationError

from app import mock_data
from app.schemas import (
    ClearRequest,
    LevelDetail,
    LevelProgress,
    LevelSummary,
    MowerSnapshot,
    PendingSpawn,
    PlantSnapshot,
    Progress,
    RunSnapshot,
    Settings,
    Wave,
    ZombieSnapshot,
    Zombie,
    Plant,
)


def _zombie_snapshot(**overrides):
    payload = {
        "type": "basic",
        "row": 0,
        "x": 1.0,
        "hp": 1,
        "has_hat": False,
        "hat_hp": 0,
        "state": 0,
        "slow_t": 0.0,
        "bite_t": 0.0,
    }
    payload.update(overrides)
    return ZombieSnapshot(**payload)


# ---------------- Settings ----------------
def test_settings_accepts_boundary_values():
    assert Settings(bgm_volume=0.0, sfx_volume=1.0, muted=False)
    assert Settings(bgm_volume=1.0, sfx_volume=0.0, muted=True).muted is True


@pytest.mark.parametrize("volume", [1.5, -0.01, 100.0])
def test_settings_rejects_out_of_range_volume(volume):
    # 契约采用严格校验，不做静默裁剪
    with pytest.raises(ValidationError):
        Settings(bgm_volume=volume, sfx_volume=1.0, muted=False)


def test_settings_requires_all_fields():
    with pytest.raises(ValidationError):
        Settings(bgm_volume=0.5, sfx_volume=1.0)


def test_settings_rejects_wrong_type():
    with pytest.raises(ValidationError):
        Settings(bgm_volume="loud", sfx_volume=1.0, muted=False)


# ---------------- Progress ----------------
def test_progress_accepts_contract_bounds():
    assert Progress(unlocked_level=0, levels={}).unlocked_level == 0
    assert Progress(unlocked_level=39, levels={}).unlocked_level == 39


@pytest.mark.parametrize("unlocked", [40, -1])
def test_progress_rejects_out_of_range_unlocked_level(unlocked):
    with pytest.raises(ValidationError):
        Progress(unlocked_level=unlocked, levels={})


def test_level_progress_rejects_negative_best_kills():
    with pytest.raises(ValidationError):
        LevelProgress(cleared=True, best_kills=-1)


# ---------------- ClearRequest ----------------
def test_clear_request_accepts_zero():
    assert ClearRequest(kills=0).kills == 0


def test_clear_request_rejects_negative_kills():
    with pytest.raises(ValidationError):
        ClearRequest(kills=-1)


# ---------------- Wave / PendingSpawn ----------------
def test_wave_accepts_known_zombies():
    assert Wave(t=20.0, z=["basic", "cone"]).huge is None


def test_wave_rejects_unknown_zombie():
    with pytest.raises(ValidationError):
        Wave(t=20.0, z=["dragon"])


def test_pending_spawn_rejects_unknown_zombie():
    with pytest.raises(ValidationError):
        PendingSpawn(dt=1.0, type="dragon")


# ---------------- ZombieSnapshot（新增 enum 校验） ----------------
def test_zombie_snapshot_accepts_known_type():
    assert _zombie_snapshot(type="cone").type == "cone"


@pytest.mark.parametrize("state", [0, 1])
def test_zombie_snapshot_accepts_valid_state(state):
    assert _zombie_snapshot(state=state).state == state


def test_zombie_snapshot_rejects_unknown_type():
    with pytest.raises(ValidationError):
        _zombie_snapshot(type="dragon")


def test_zombie_snapshot_rejects_invalid_state():
    with pytest.raises(ValidationError):
        _zombie_snapshot(state=2)


def test_zombie_snapshot_rejects_row_out_of_range():
    with pytest.raises(ValidationError):
        _zombie_snapshot(row=5)


# ---------------- RunSnapshot ----------------
def test_run_snapshot_accepts_contract_example():
    assert RunSnapshot(**copy.deepcopy(mock_data.INITIAL_SNAPSHOT)).version == 1


def test_run_snapshot_requires_wave():
    payload = copy.deepcopy(mock_data.INITIAL_SNAPSHOT)
    payload.pop("wave")
    with pytest.raises(ValidationError):
        RunSnapshot(**payload)


def test_run_snapshot_rejects_unknown_zombie_type_in_grid():
    payload = copy.deepcopy(mock_data.INITIAL_SNAPSHOT)
    payload["zombies"][0]["type"] = "dragon"
    with pytest.raises(ValidationError):
        RunSnapshot(**payload)


def test_run_snapshot_version_conflict_is_route_level_concern():
    # schema 只要求 version 为整数；版本兼容性由路由判定（返回 2003）
    payload = copy.deepcopy(mock_data.INITIAL_SNAPSHOT)
    payload["version"] = 2
    assert RunSnapshot(**payload).version == 2


def test_run_snapshot_rejects_too_many_plants():
    payload = copy.deepcopy(mock_data.INITIAL_SNAPSHOT)
    payload["plants"] = [{"type": "sunflower", "col": 0, "row": 0, "hp": 1, "state": {}}] * 46
    with pytest.raises(ValidationError):
        RunSnapshot(**payload)


# ---------------- 图鉴 / 关卡结构模型 ----------------
def test_plant_model_bounds():
    assert Plant(**mock_data.PLANTS[0]).id == "sunflower"
    with pytest.raises(ValidationError):
        Plant(id="x", name="x", cost=0, hp=0, recharge=0.0, unlock_level=0)


def test_zombie_model_accepts_optional_keys():
    assert Zombie(**mock_data.ZOMBIES_BY_ID["pole"]).jump == "z_pole_jump"


def test_level_summary_bounds_and_required_name():
    good = {
        "id": 0, "name": "第1关 · 初次防守", "difficulty": 1, "start_sun": 100,
        "scene": "day", "cleared": False, "best_kills": 0, "unlocked": True,
    }
    assert LevelSummary(**good).id == 0
    with pytest.raises(ValidationError):
        LevelSummary(**{**good, "id": 40})
    with pytest.raises(ValidationError):
        LevelSummary(**{**good, "name": ""})
    with pytest.raises(ValidationError):
        LevelSummary(**{**good, "difficulty": 0})


def test_level_detail_waves_bounds():
    detail = {
        "id": 0, "name": "第1关 · 初次防守", "difficulty": 1, "start_sun": 100,
        "scene": "day",
        "waves": [{"t": 20.0, "z": ["basic"]}],
        "available_plants": ["sunflower", "peashooter"],
        "seed_slot_limit": 2, "needs_seed_select": False, "zombies": ["basic"],
    }
    assert LevelDetail(**detail).seed_slot_limit == 2
    with pytest.raises(ValidationError):
        LevelDetail(**{**detail, "waves": []})


def test_mower_and_plant_snapshot_models():
    assert MowerSnapshot(row=0, used=False, running=False, x=520.0).row == 0
    assert PlantSnapshot(type="sunflower", col=0, row=2, hp=300, state={}).state == {}
