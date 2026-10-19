"""集成测试：/progress 与 /progress/levels/{index}/clear（正常 / 边界 / 异常）。"""

import pytest


def test_get_progress_matches_contract_example(client):
    response = client.get("/api/progress")
    assert response.status_code == 200
    assert response.json() == {
        "code": 0,
        "msg": "ok",
        "data": {
            "unlocked_level": 2,
            "levels": {
                "0": {"cleared": True, "best_kills": 18},
                "1": {"cleared": True, "best_kills": 24},
            },
        },
    }


def test_put_progress_overwrites_and_persists(client):
    payload = {"unlocked_level": 5, "levels": {"5": {"cleared": False, "best_kills": 3}}}
    response = client.put("/api/progress", json=payload)
    assert response.status_code == 200
    assert response.json() == {"code": 0, "msg": "进度已保存", "data": payload}
    assert client.get("/api/progress").json()["data"] == payload


def test_put_progress_accepts_empty_levels_and_bounds(client):
    assert client.put("/api/progress", json={"unlocked_level": 0, "levels": {}}).status_code == 200
    assert client.put("/api/progress", json={"unlocked_level": 39, "levels": {}}).status_code == 200


@pytest.mark.parametrize(
    "payload",
    [
        {"unlocked_level": 40, "levels": {}},
        {"unlocked_level": -1, "levels": {}},
        {"unlocked_level": 1, "levels": {"0": {"cleared": True, "best_kills": -1}}},
        {"levels": {}},
    ],
)
def test_put_progress_validation_failed(client, payload):
    # PUT /progress 的 400 契约错误码为 4002（ValidationFailed）
    response = client.put("/api/progress", json=payload)
    assert response.status_code == 400
    assert response.json() == {"code": 4002, "msg": "校验失败", "data": None}


def test_clear_level_reports_and_unlocks_next(client):
    response = client.post("/api/progress/levels/2/clear", json={"kills": 30})
    assert response.status_code == 200
    assert response.json() == {
        "code": 0,
        "msg": "通关已记录",
        "data": {"unlocked_level": 3, "level": {"cleared": True, "best_kills": 30}},
    }
    progress = client.get("/api/progress").json()["data"]
    assert progress["unlocked_level"] == 3
    assert progress["levels"]["2"] == {"cleared": True, "best_kills": 30}


def test_clear_level_keeps_historical_best_kills(client):
    response = client.post("/api/progress/levels/0/clear", json={"kills": 5})
    assert response.json()["data"]["level"]["best_kills"] == 18


def test_clear_level_accepts_zero_kills(client):
    assert client.post("/api/progress/levels/2/clear", json={"kills": 0}).status_code == 200


def test_clear_level_caps_unlock_at_last_index(client):
    client.put("/api/progress", json={"unlocked_level": 39, "levels": {}})
    response = client.post("/api/progress/levels/39/clear", json={"kills": 1})
    assert response.json()["data"]["unlocked_level"] == 39


def test_clear_level_locked_returns_3002(client):
    # 初始 unlocked_level = 2，下标 9 尚未解锁
    response = client.post("/api/progress/levels/9/clear", json={"kills": 1})
    assert response.status_code == 409
    assert response.json() == {"code": 3002, "msg": "关卡未解锁", "data": None}


@pytest.mark.parametrize("index", [40, -1, 999])
def test_clear_level_out_of_range_returns_3001(client, index):
    response = client.post(f"/api/progress/levels/{index}/clear", json={"kills": 1})
    assert response.status_code == 404
    assert response.json() == {"code": 3001, "msg": "关卡不存在", "data": None}


@pytest.mark.parametrize("payload", [{"kills": -1}, {}])
def test_clear_level_bad_body_returns_4001(client, payload):
    response = client.post("/api/progress/levels/2/clear", json=payload)
    assert response.status_code == 400
    assert response.json() == {"code": 4001, "msg": "参数非法", "data": None}
