"""集成测试：/levels 与 /levels/{index}（正常 / 边界 / 异常）。"""

import pytest

from app import mock_data


def test_list_levels_returns_all_with_progress(client):
    data = client.get("/api/levels").json()["data"]
    assert len(data) == 40
    assert data[0] == {
        "id": 0, "name": "第1关 · 初次防守", "difficulty": 1, "start_sun": 100,
        "scene": "day", "cleared": True, "best_kills": 18, "unlocked": True,
    }
    # 已解锁但未通关
    assert data[2]["cleared"] is False
    assert data[2]["best_kills"] == 0
    assert data[2]["unlocked"] is True
    # 未解锁的夜景关
    assert data[15]["scene"] == "night"
    assert data[15]["unlocked"] is False


def test_get_level_zero_matches_contract_example(client):
    data = client.get("/api/levels/0").json()["data"]
    assert data["id"] == 0
    assert data["waves"] == [
        {"t": 20.0, "z": ["basic"]},
        {"t": 55.0, "z": ["basic", "basic"]},
        {"t": 95.0, "z": ["basic", "basic", "basic"], "huge": True},
    ]
    assert data["available_plants"] == ["sunflower", "peashooter"]
    assert data["seed_slot_limit"] == 2
    assert data["needs_seed_select"] is False
    assert data["zombies"] == ["basic"]


def test_needs_seed_select_starts_at_level_7(client):
    assert client.get("/api/levels/5").json()["data"]["needs_seed_select"] is False
    assert client.get("/api/levels/6").json()["data"]["needs_seed_select"] is True


def test_night_level_reports_night_scene(client):
    assert client.get("/api/levels/15").json()["data"]["scene"] == "night"


@pytest.mark.parametrize("index", [40, -1, 100])
def test_get_level_out_of_range_returns_3001(client, index):
    response = client.get(f"/api/levels/{index}")
    assert response.status_code == 404
    assert response.json() == {"code": 3001, "msg": "关卡不存在", "data": None}


def test_get_level_plants_boundaries(client):
    assert client.get("/api/levels/0/plants").json()["data"] == ["sunflower", "peashooter"]
    # 第 21 关（level_id 21）起甜菜解锁，列表末位为 beetroot
    assert client.get("/api/levels/20/plants").json()["data"][-1] == "beetroot"
    # 最后一关全部 13 种植物开放，且顺序等于 PLANT_ORDER
    assert client.get("/api/levels/39/plants").json()["data"] == mock_data.PLANT_ORDER


def test_get_level_plants_out_of_range_returns_3001(client):
    response = client.get("/api/levels/40/plants")
    assert response.status_code == 404
    assert response.json()["code"] == 3001


def test_every_level_detail_respects_contract_bounds(client):
    for index in range(40):
        data = client.get(f"/api/levels/{index}").json()["data"]
        assert 1 <= len(data["waves"]) <= 12
        assert len(data["available_plants"]) <= 13
        assert 1 <= data["seed_slot_limit"] <= 10
        assert set(data["zombies"]).isdisjoint({"flag"})
        assert 1 <= data["difficulty"] <= 10
