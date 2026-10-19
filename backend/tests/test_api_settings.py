"""集成测试：GET / PUT /settings（正常 / 边界 / 异常）。"""

import pytest

VALID = {"bgm_volume": 0.3, "sfx_volume": 0.4, "muted": True}
DEFAULTS = {"bgm_volume": 0.8, "sfx_volume": 1.0, "muted": False}


def test_get_default_settings(client):
    response = client.get("/api/settings")
    assert response.status_code == 200
    assert response.json() == {"code": 0, "msg": "ok", "data": DEFAULTS}


def test_put_settings_persists_and_returns_saved_value(client):
    response = client.put("/api/settings", json=VALID)
    assert response.status_code == 200
    assert response.json() == {"code": 0, "msg": "设置已保存", "data": VALID}
    assert client.get("/api/settings").json()["data"] == VALID


@pytest.mark.parametrize(
    "payload",
    [
        {"bgm_volume": 0.0, "sfx_volume": 1.0, "muted": False},
        {"bgm_volume": 1.0, "sfx_volume": 0.0, "muted": True},
    ],
)
def test_put_settings_accepts_boundary_volumes(client, payload):
    assert client.put("/api/settings", json=payload).status_code == 200


@pytest.mark.parametrize(
    "payload",
    [
        {"bgm_volume": 1.5, "sfx_volume": 1.0, "muted": False},
        {"bgm_volume": -0.01, "sfx_volume": 1.0, "muted": False},
        {"sfx_volume": 1.0, "muted": False},
        {"bgm_volume": "loud", "sfx_volume": 1.0, "muted": False},
    ],
)
def test_put_settings_rejects_invalid_payload(client, payload):
    # 契约采用严格校验：越界 / 缺字段 / 类型错误一律 400（ErrorCode 4001）
    response = client.put("/api/settings", json=payload)
    assert response.status_code == 400
    assert response.json() == {"code": 4001, "msg": "参数非法", "data": None}
    # 失败请求不改变已有设置
    assert client.get("/api/settings").json()["data"] == DEFAULTS
