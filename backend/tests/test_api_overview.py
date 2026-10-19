"""集成测试：GET /overview（主菜单聚合数据）。"""


def test_overview_aggregates_progress_latest_save_and_settings(client):
    response = client.get("/api/overview")
    assert response.status_code == 200

    body = response.json()
    assert set(body) == {"code", "msg", "data"}
    assert body["code"] == 0
    assert body["msg"] == "ok"

    data = body["data"]
    assert data["unlocked_level"] == 2
    assert data["total_levels"] == 40
    assert data["cleared_levels"] == 2
    assert data["total_best_kills"] == 42
    assert data["latest_save"] == {
        "slot": 1,
        "level_index": 2,
        "level_name": "第3关 · 铁桶初现",
        "time": 132.5,
        "sun": 275,
        "killed": 18,
        "saved_at": "2026-10-10T20:15:30",
    }
    assert data["settings"] == {"bgm_volume": 0.8, "sfx_volume": 1.0, "muted": False}


def test_overview_reflects_settings_update(client):
    client.put("/api/settings", json={"bgm_volume": 0.1, "sfx_volume": 0.2, "muted": True})
    data = client.get("/api/overview").json()["data"]
    assert data["settings"] == {"bgm_volume": 0.1, "sfx_volume": 0.2, "muted": True}


def test_overview_latest_save_is_null_after_all_slots_deleted(client):
    for slot in (1, 2, 3):
        client.delete(f"/api/saves/{slot}")
    data = client.get("/api/overview").json()["data"]
    assert data["latest_save"] is None
