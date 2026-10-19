"""集成测试：/audio 与 /sprites（资源清单）。"""

from app import mock_data


def test_get_audio_matches_sound_manager(client):
    data = client.get("/api/audio").json()["data"]
    assert data["bgm"] == {"name": "background", "path": "res://assets/sounds/background.wav"}
    assert len(data["sfx"]) == 10
    assert [track["name"] for track in data["sfx"]] == [track["name"] for track in mock_data.SOUNDS]
    assert data["pool_size"] == 8
    assert data["sfx_volume_db"] == -6.0
    assert data["bgm_volume_db"] == -16.0
    for track in data["sfx"]:
        assert track["path"].startswith("res://assets/sounds/")
        assert track["path"].endswith(".wav")


def test_get_sprites_matches_sprite_library(client):
    data = client.get("/api/sprites").json()["data"]
    assert len(data["sheets"]) == len(mock_data.SHEETS) == 46
    assert len(data["static_textures"]) == 7
    assert len(data["card_textures"]) == 13
    assert len(data["card_regions"]) == 1

    sunflower = next(sheet for sheet in data["sheets"] if sheet["name"] == "sunflower")
    assert sunflower == {
        "name": "sunflower", "w": 73, "h": 74, "frames": 18,
        "d": 0.11, "src": "res://assets/sprites/sunflower.png",
    }

    # 单独维护 delays 的精灵表不再带统一帧时长 d
    walnut_low = next(sheet for sheet in data["sheets"] if sheet["name"] == "walnut_low")
    assert "delays" in walnut_low
    assert "d" not in walnut_low

    assert data["card_regions"][0] == {
        "name": "melonpult", "x": 0.0, "y": 0.0, "w": 100.0, "h": 60.0,
    }
    for sheet in data["sheets"]:
        assert sheet["src"].startswith("res://assets/sprites/")
        assert sheet["src"].endswith(".png")
    for texture in data["static_textures"]:
        assert texture["path"].startswith("res://assets/")
        assert texture["path"].endswith(".png")
