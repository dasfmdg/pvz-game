"""单元测试：关卡派生逻辑（与 game_config.gd 的公式 / 源数据保持一致）。

派生公式已下沉到 `app.repositories.base`，内存后端与 MySQL 后端共用同一套实现，
本模块直接对公式与源数据做校验。
"""

from app import mock_data
from app.repositories.base import (
    derive_available_plants,
    derive_seed_slot_limit,
    derive_zombies_for_level,
)

RULES = {
    "seed_slot_base": mock_data.SEED_SLOT_BASE,
    "seed_slot_step": mock_data.SEED_SLOT_STEP,
    "seed_slot_max": mock_data.SEED_SLOT_MAX,
}


def _plants_for_level(level_id: int) -> list[str]:
    return derive_available_plants(mock_data.PLANT_ORDER, mock_data.PLANT_UNLOCK, level_id)


def _seed_slot_limit(level_id: int) -> int:
    return derive_seed_slot_limit(len(_plants_for_level(level_id)), level_id, RULES)


def _zombies_for_level(index: int) -> list[str]:
    return derive_zombies_for_level(
        mock_data.LEVELS_BY_ID[index]["waves"], set(mock_data.ZOMBIES_BY_ID)
    )


def _expected_plants(level_id: int) -> list[str]:
    """game_config.plants_for_level：PLANT_UNLOCK 中 unlock_level <= level_id 的植物。"""
    return [pid for pid in mock_data.PLANT_ORDER if mock_data.PLANT_UNLOCK.get(pid, 0) <= level_id]


# ---------------- plants_for_level ----------------
def test_first_level_only_starter_plants():
    assert _plants_for_level(1) == ["sunflower", "peashooter"]


def test_plants_for_level_matches_formula_across_all_levels():
    for level_id in range(1, 41):
        assert _plants_for_level(level_id) == _expected_plants(level_id)


def test_unlocked_plant_count_is_monotonic_and_saturates():
    sizes = [len(_plants_for_level(level_id)) for level_id in range(1, 41)]
    assert sizes == sorted(sizes)
    assert sizes[-1] == len(mock_data.PLANT_ORDER)


# ---------------- seed_slot_limit ----------------
def test_seed_slot_limit_known_samples():
    # 与 README 记录的曲线一致：第 7 关 6 / 第 11 关 7 / 第 17 关 9 / 第 21 关起封顶 10
    assert _seed_slot_limit(1) == 2
    assert _seed_slot_limit(7) == 6
    assert _seed_slot_limit(11) == 7
    assert _seed_slot_limit(17) == 9
    assert _seed_slot_limit(21) == 10
    assert _seed_slot_limit(25) == 10


def test_seed_slot_limit_always_within_1_to_max():
    for level_id in range(1, 41):
        assert 1 <= _seed_slot_limit(level_id) <= mock_data.SEED_SLOT_MAX


# ---------------- zombies_for_level ----------------
def test_first_level_zombies_is_basic_only():
    assert _zombies_for_level(0) == ["basic"]


def test_zombies_dedup_in_first_appearance_order():
    assert _zombies_for_level(2) == ["basic", "cone", "bucket"]


def test_flag_never_listed():
    for index in range(40):
        assert "flag" not in _zombies_for_level(index)


def test_needs_seed_select_threshold_is_seventh_level():
    assert mock_data.SEED_SELECT_FROM_LEVEL == 7
    assert not (0 + 1 >= mock_data.SEED_SELECT_FROM_LEVEL)
    assert 6 + 1 >= mock_data.SEED_SELECT_FROM_LEVEL


# ---------------- 源数据完整性 ----------------
def test_levels_are_0_based_and_count_40():
    assert len(mock_data.LEVELS) == 40
    assert [level["id"] for level in mock_data.LEVELS] == list(range(40))


def test_catalog_counts_match_contract_max_items():
    assert len(mock_data.PLANTS) == len(mock_data.PLANT_ORDER) == 13
    assert len(mock_data.ZOMBIES) == 8
    assert len(mock_data.SHEETS) <= 60
    assert len(mock_data.STATIC_TEXTURES) <= 20
    assert len(mock_data.CARD_TEXTURES) <= 20
    assert len(mock_data.CARD_REGIONS) <= 20
    assert len(mock_data.SOUNDS) == 10


def test_every_level_respects_contract_bounds():
    for level in mock_data.LEVELS:
        assert 1 <= level["difficulty"] <= 10
        assert 1 <= len(level["waves"]) <= 12
        for wave in level["waves"]:
            assert 1 <= len(wave["z"]) <= 20
            for zombie_id in wave["z"]:
                assert zombie_id in mock_data.ZOMBIES_BY_ID


def test_night_levels_match_game_config():
    nights = [level["id"] for level in mock_data.LEVELS if level.get("scene") == "night"]
    assert nights == [15, 20, 23, 25, 27, 29, 32, 34, 37, 39]


def test_plant_unlock_table_and_order_are_consistent():
    assert set(mock_data.PLANT_UNLOCK) == set(mock_data.PLANT_ORDER)
    assert set(mock_data.PLANT_BEHAVIOR) <= set(mock_data.PLANT_ORDER)
    assert mock_data.SEED_SLOT_BASE == 5
    assert mock_data.SEED_SLOT_STEP == 4
    assert mock_data.SEED_SLOT_MAX == 10
    assert mock_data.SEED_SELECT_FROM_LEVEL == 7


def test_error_code_rows_match_enum_and_defaults():
    from app.errors import _DEFAULT_MSG, _HTTP_STATUS, ErrorCode

    rows = {code: (status, message) for code, status, message, _ in mock_data.ERROR_CODE_ROWS}
    assert set(rows) == {int(code) for code in ErrorCode}
    for code in ErrorCode:
        status, message = rows[int(code)]
        assert status == _HTTP_STATUS[code]
        assert message == _DEFAULT_MSG[code]
