"""MySQL 后端专项测试：真实库行为、持久化证据、以及路由在 mysql 后端下的契约一致性。

数据库不可用时整模块 skip（不把「没库」误报成「失败」，也不把「没跑」说成「通过」）。
"""

from __future__ import annotations

import copy
import os

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import delete, select, update

from app import mock_data
from app.main import app
from app.repositories import get_repository, reset_repository
from app.repositories.mysql_repository import LOCAL_PLAYER_UID, MySqlRepository
from db import seed as seed_module
from db.session import get_engine, get_metadata


def _reset_player_state() -> None:
    """把玩家态复位到"出厂初始值"，与内存后端的 store.state.__init__() 等价。"""
    engine = get_engine()
    metadata = get_metadata()
    repository = MySqlRepository()
    with engine.begin() as conn:
        # run_save_* 对 run_saves 是 ON DELETE CASCADE，删父表即可联动清理子表
        conn.execute(delete(metadata.tables["run_saves"]))
        conn.execute(delete(metadata.tables["player_level_progress"]))
        conn.execute(delete(metadata.tables["level_clear_events"]))
        players = metadata.tables["players"]
        player_id = conn.execute(
            select(players.c.id).where(players.c.player_uid == LOCAL_PLAYER_UID)
        ).scalar_one_or_none()
        if player_id is not None:
            settings = metadata.tables["player_settings"]
            progress = metadata.tables["player_progress"]
            conn.execute(
                update(settings)
                .where(settings.c.player_id == player_id)
                .values(bgm_volume=0.8, sfx_volume=1.0, muted=0)
            )
            conn.execute(
                update(progress).where(progress.c.player_id == player_id).values(unlocked_level=0)
            )
    seed_module._seed_initial_player(engine, repository)


@pytest.fixture
def mysql_env(monkeypatch):
    """切到 MySQL 后端并复位玩家态；数据库不可达则 skip。"""
    monkeypatch.setenv("PVZ_STORE", "mysql")
    reset_repository()
    try:
        get_metadata()
    except Exception as error:  # noqa: BLE001 - 任何连接类异常都视为"库不可用"
        pytest.skip(f"MySQL 不可用，跳过：{error}")
    _reset_player_state()
    yield
    reset_repository()


@pytest.fixture
def mysql_repository(mysql_env) -> MySqlRepository:
    return MySqlRepository()


# ---------------- 设置 / 进度 ----------------
def test_settings_roundtrip(mysql_repository):
    assert mysql_repository.get_settings() == {"bgm_volume": 0.8, "sfx_volume": 1.0, "muted": False}
    saved = mysql_repository.put_settings({"bgm_volume": 0.25, "sfx_volume": 0.5, "muted": True})
    assert saved == {"bgm_volume": 0.25, "sfx_volume": 0.5, "muted": True}
    assert mysql_repository.get_settings() == saved


def test_progress_roundtrip(mysql_repository):
    assert mysql_repository.get_progress() == mock_data.INITIAL_PROGRESS
    payload = {"unlocked_level": 5, "levels": {"5": {"cleared": False, "best_kills": 3}}}
    assert mysql_repository.put_progress(payload) == payload
    assert mysql_repository.get_progress() == payload


def test_clear_level_updates_progress_and_writes_event(mysql_repository):
    unlocked, level = mysql_repository.clear_level(2, 30)
    assert unlocked == 3
    assert level == {"cleared": True, "best_kills": 30}
    progress = mysql_repository.get_progress()
    assert progress["unlocked_level"] == 3
    assert progress["levels"]["2"] == {"cleared": True, "best_kills": 30}

    metadata = get_metadata()
    events = metadata.tables["level_clear_events"]
    with get_engine().connect() as conn:
        rows = conn.execute(select(events.c.level_index, events.c.kills)).all()
    assert (2, 30) in [(int(row.level_index), int(row.kills)) for row in rows]


def test_clear_level_keeps_higher_best_kills(mysql_repository):
    _, level = mysql_repository.clear_level(0, 5)
    assert level["best_kills"] == 18  # 既有的 18 不被 5 拉低


def test_clear_level_caps_unlock_at_last_index(mysql_repository):
    mysql_repository.put_progress({"unlocked_level": 39, "levels": {}})
    unlocked, _ = mysql_repository.clear_level(39, 1)
    assert unlocked == 39


# ---------------- 存档全图往返 ----------------
def test_save_slot_roundtrip_matches_contract_example(mysql_repository):
    detail = mysql_repository.get_slot(1)
    assert detail is not None
    assert detail["saved_at"] == mock_data.INITIAL_SAVE_SAVED_AT
    assert detail["snapshot"] == mock_data.INITIAL_SNAPSHOT


def test_save_slot_overwrite_and_delete(mysql_repository):
    snapshot = copy.deepcopy(mock_data.INITIAL_SNAPSHOT)
    snapshot["sun"] = 999
    snapshot["zombies"][0]["has_hat"] = True
    snapshot["zombies"][0]["hat_hp"] = 300
    assert mysql_repository.put_slot(2, snapshot, "2026-10-20T10:00:00") == "2026-10-20T10:00:00"

    stored = mysql_repository.get_slot(2)
    assert stored["snapshot"] == snapshot

    slots = mysql_repository.list_slots()
    assert slots[1]["slot"] == 2 and "empty" not in slots[1]
    assert mysql_repository.delete_slot(2) is True
    assert mysql_repository.get_slot(2) is None
    assert mysql_repository.delete_slot(2) is False
    assert mysql_repository.list_slots()[1] == {"slot": 2, "empty": True}


def test_latest_save_picks_most_recent(mysql_repository):
    snapshot = copy.deepcopy(mock_data.INITIAL_SNAPSHOT)
    mysql_repository.put_slot(2, snapshot, "2026-10-21T09:00:00")
    assert mysql_repository.latest_save()["slot"] == 2


# ---------------- 元数据与派生 ----------------
def test_level_list_and_detail_from_database(mysql_repository):
    levels = mysql_repository.list_levels()
    assert len(levels) == 40
    assert levels[0] == {
        "id": 0, "name": "第1关 · 初次防守", "difficulty": 1, "start_sun": 100,
        "scene": "day", "cleared": True, "best_kills": 18, "unlocked": True,
    }
    detail = mysql_repository.get_level(0)
    assert detail["waves"] == [
        {"t": 20.0, "z": ["basic"]},
        {"t": 55.0, "z": ["basic", "basic"]},
        {"t": 95.0, "z": ["basic", "basic", "basic"], "huge": True},
    ]
    assert detail["available_plants"] == ["sunflower", "peashooter"]
    assert detail["seed_slot_limit"] == 2
    assert detail["needs_seed_select"] is False
    assert detail["zombies"] == ["basic"]
    assert mysql_repository.get_level(40) is None
    assert mysql_repository.get_level_plants(0) == ["sunflower", "peashooter"]
    assert mysql_repository.get_level_plants(40) is None


def test_derived_seed_slot_limit_matches_memory_backend(mysql_repository):
    # 与内存后端共用同一套公式：第 21 关起封顶 10 张
    assert mysql_repository.get_level(6)["needs_seed_select"] is True
    assert mysql_repository.get_level(20)["seed_slot_limit"] == 10
    assert mysql_repository.get_level(11)["seed_slot_limit"] == 7


def test_catalogs_from_database(mysql_repository):
    plants = mysql_repository.list_plants()
    assert [plant["id"] for plant in plants] == mock_data.PLANT_ORDER
    assert plants[0] == mock_data.PLANTS_BY_ID["sunflower"]

    zombies = mysql_repository.list_zombies()
    assert len(zombies) == 8
    assert {zombie["id"] for zombie in zombies} == set(mock_data.ZOMBIES_BY_ID)
    assert mysql_repository.get_zombie("pole")["jump"] == "z_pole_jump"
    assert mysql_repository.get_zombie("newspaper")["rip"] == "z_newspaper_rip"
    assert mysql_repository.get_zombie("flag")["has_flag"] is True
    assert mysql_repository.get_zombie("dragon") is None


def test_resources_from_database(mysql_repository):
    audio = mysql_repository.get_audio()
    assert audio["bgm"] == {"name": "background", "path": mock_data.BGM_PATH}
    assert audio["sfx"] == mock_data.SOUNDS
    assert audio["pool_size"] == 8
    assert audio["sfx_volume_db"] == -6.0
    assert audio["bgm_volume_db"] == -16.0

    sprites = mysql_repository.get_sprites()
    assert len(sprites["sheets"]) == len(mock_data.SHEETS)
    sunflower = next(sheet for sheet in sprites["sheets"] if sheet["name"] == "sunflower")
    assert sunflower == {
        "name": "sunflower", "w": 73, "h": 74, "frames": 18,
        "d": 0.11, "src": "res://assets/sprites/sunflower.png",
    }
    walnut_low = next(sheet for sheet in sprites["sheets"] if sheet["name"] == "walnut_low")
    assert "delays" in walnut_low and "d" not in walnut_low
    assert sprites["static_textures"] == mock_data.STATIC_TEXTURES
    assert sprites["card_textures"] == mock_data.CARD_TEXTURES
    assert sprites["card_regions"] == mock_data.CARD_REGIONS


# ---------------- 持久化证据（内存态做不到） ----------------
def test_data_survives_new_engine_and_repository():
    """写入后丢弃 engine 与仓储对象，重新建连再读——数据仍在，证明落的是库不是内存。"""
    from db.session import dispose

    first = MySqlRepository()
    first.put_settings({"bgm_volume": 0.11, "sfx_volume": 0.22, "muted": True})
    del first
    dispose()  # 丢掉连接池与反射缓存

    second = MySqlRepository()
    assert second.get_settings() == {"bgm_volume": 0.11, "sfx_volume": 0.22, "muted": True}


# ---------------- 路由在 mysql 后端下的契约一致性 ----------------
def test_http_smoke_over_mysql_backend(mysql_env):
    with TestClient(app) as client:
        assert client.get("/api/overview").json()["data"]["total_levels"] == 40
        assert client.get("/api/settings").json()["data"] == {
            "bgm_volume": 0.8, "sfx_volume": 1.0, "muted": False
        }
        assert client.get("/api/progress").json()["data"] == mock_data.INITIAL_PROGRESS
        assert client.get("/api/saves/1").json()["data"]["snapshot"] == mock_data.INITIAL_SNAPSHOT
        assert client.get("/api/saves/2").status_code == 404
        assert client.get("/api/saves/9").json()["code"] == 2002
        assert client.get("/api/levels/40").json()["code"] == 3001
        assert client.get("/api/zombies/dragon").json()["code"] == 4003
        assert client.get("/api/levels/0/plants").json()["data"] == ["sunflower", "peashooter"]
        assert len(client.get("/api/plants").json()["data"]) == 13
        assert len(client.get("/api/sprites").json()["data"]["sheets"]) == 46

        # 写路径也过一遍：PUT /settings 越界 -> 4001；越级通关 -> 3002；快照版本 -> 2003
        assert client.put("/api/settings", json={"bgm_volume": 1.5, "sfx_volume": 1.0, "muted": False}).json()["code"] == 4001
        assert client.post("/api/progress/levels/39/clear", json={"kills": 1}).json()["code"] == 3002

        snapshot = copy.deepcopy(mock_data.INITIAL_SNAPSHOT)
        snapshot["version"] = 2
        assert client.put("/api/saves/2", json={"snapshot": snapshot}).json()["code"] == 2003

        snapshot["version"] = 1
        assert client.put("/api/saves/2", json={"snapshot": snapshot}).json()["data"] == {"slot": 2}
        assert client.delete("/api/saves/2").json()["code"] == 0


def test_declared_store_switch_is_respected(mysql_env):
    assert os.environ["PVZ_STORE"] == "mysql"
    assert isinstance(get_repository(), MySqlRepository)
