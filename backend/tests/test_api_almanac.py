"""集成测试：/plants、/zombies、/zombies/{id}（图鉴）。"""

from app import mock_data


def test_list_plants_order_and_shape(client):
    data = client.get("/api/plants").json()["data"]
    assert len(data) == 13
    assert [plant["id"] for plant in data] == mock_data.PLANT_ORDER
    assert data[0] == {
        "id": "sunflower", "name": "Sunflower", "cost": 50,
        "hp": 300, "recharge": 5.0, "unlock_level": 0,
    }
    for plant in data:
        assert set(plant) == {"id", "name", "cost", "hp", "recharge", "unlock_level"}


def test_list_zombies_order_and_required_keys(client):
    data = client.get("/api/zombies").json()["data"]
    assert [zombie["id"] for zombie in data] == [
        "basic", "cone", "bucket", "football", "door", "flag", "pole", "newspaper",
    ]
    for zombie in data:
        assert {"id", "name", "hp", "speed", "zw", "zh", "walk", "attack"} <= set(zombie)


def test_get_zombie_optional_keys(client):
    pole = client.get("/api/zombies/pole").json()["data"]
    assert pole["jump"] == "z_pole_jump"
    assert pole["after_jump_walk"] == "z_pole_after_jump"

    newspaper = client.get("/api/zombies/newspaper").json()["data"]
    assert newspaper["rip"] == "z_newspaper_rip"

    assert client.get("/api/zombies/flag").json()["data"]["has_flag"] is True


def test_get_zombie_not_found_returns_4003(client):
    response = client.get("/api/zombies/dragon")
    assert response.status_code == 404
    assert response.json() == {"code": 4003, "msg": "僵尸类型不存在", "data": None}
