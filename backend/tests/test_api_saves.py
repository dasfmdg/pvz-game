"""集成测试：/saves 与 /saves/{slot}（正常 / 边界 / 异常）。"""

import copy

import pytest

from app import mock_data


def _snapshot(**overrides):
    snapshot = copy.deepcopy(mock_data.INITIAL_SNAPSHOT)
    snapshot.update(overrides)
    return snapshot


def test_list_saves_returns_three_slots(client):
    response = client.get("/api/saves")
    assert response.status_code == 200
    body = response.json()
    assert body["code"] == 0
    data = body["data"]
    assert [item["slot"] for item in data] == [1, 2, 3]
    assert data[0]["level_index"] == 2
    assert data[1] == {"slot": 2, "empty": True}
    assert data[2] == {"slot": 3, "empty": True}


def test_get_slot_returns_full_detail(client):
    response = client.get("/api/saves/1")
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["slot"] == 1
    assert data["saved_at"] == "2026-10-10T20:15:30"
    snapshot = data["snapshot"]
    assert snapshot["version"] == 1
    assert snapshot["level_index"] == 2
    assert snapshot["wave"]["index"] == 3
    assert len(snapshot["plants"]) == 2
    assert len(snapshot["zombies"]) == 1
    assert len(snapshot["mowers"]) == 1


def test_get_empty_slot_returns_2001(client):
    response = client.get("/api/saves/2")
    assert response.status_code == 404
    assert response.json() == {"code": 2001, "msg": "该槽位暂无存档", "data": None}


@pytest.mark.parametrize("slot", [0, 4, 9])
def test_get_invalid_slot_returns_2002(client, slot):
    response = client.get(f"/api/saves/{slot}")
    assert response.status_code == 400
    assert response.json() == {"code": 2002, "msg": "存档槽位非法", "data": None}


def test_upsert_slot_then_read_back(client):
    response = client.put("/api/saves/2", json={"snapshot": _snapshot(sun=999)})
    assert response.status_code == 200
    assert response.json() == {"code": 0, "msg": "存档成功", "data": {"slot": 2}}

    detail = client.get("/api/saves/2").json()["data"]
    assert detail["slot"] == 2
    assert detail["snapshot"]["sun"] == 999
    # 列表里槽位 2 不再是空
    slots = client.get("/api/saves").json()["data"]
    assert "empty" not in slots[1]


@pytest.mark.parametrize("slot", [0, 4])
def test_upsert_invalid_slot_returns_2002(client, slot):
    response = client.put(f"/api/saves/{slot}", json={"snapshot": _snapshot()})
    assert response.status_code == 400
    assert response.json() == {"code": 2002, "msg": "存档槽位非法", "data": None}


def test_upsert_snapshot_version_conflict_returns_2003(client):
    response = client.put("/api/saves/2", json={"snapshot": _snapshot(version=2)})
    assert response.status_code == 409
    assert response.json() == {"code": 2003, "msg": "快照版本不兼容", "data": None}


@pytest.mark.parametrize("payload", [{}, {"snapshot": {}}])
def test_upsert_bad_body_returns_4001(client, payload):
    response = client.put("/api/saves/2", json=payload)
    assert response.status_code == 400
    assert response.json() == {"code": 4001, "msg": "参数非法", "data": None}


def test_upsert_rejects_unknown_zombie_type(client):
    snapshot = _snapshot()
    snapshot["zombies"][0]["type"] = "dragon"
    response = client.put("/api/saves/2", json={"snapshot": snapshot})
    assert response.status_code == 400
    assert response.json() == {"code": 4001, "msg": "参数非法", "data": None}


def test_delete_slot_lifecycle(client):
    assert client.delete("/api/saves/1").json() == {"code": 0, "msg": "已删除存档", "data": None}
    assert client.get("/api/saves/1").status_code == 404
    # 再删同一位 -> 2001
    again = client.delete("/api/saves/1")
    assert again.status_code == 404
    assert again.json() == {"code": 2001, "msg": "该槽位暂无存档", "data": None}
    # 非法槽位 -> 2002
    bad = client.delete("/api/saves/7")
    assert bad.status_code == 400
    assert bad.json() == {"code": 2002, "msg": "存档槽位非法", "data": None}
