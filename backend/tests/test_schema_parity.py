"""Schema 一致性测试：pvz_game.dbml ↔ backend/db/schema.sql ↔ 真实库。

三段链路的每一环都被锁住，避免出现「DBML 改了、DDL 没跟上」或「DDL 改了、库里还是旧结构」。
"""

from __future__ import annotations

import re

import pytest
from sqlalchemy import text

from db.generate_schema import DBML_PATH, OUTPUT_PATH, order_tables, parse_dbml, render
from db.session import get_engine, get_metadata

TABLE_BLOCK = re.compile(r"CREATE TABLE IF NOT EXISTS `(\w+)` \((.*?)\n\) ENGINE", re.S)
COLUMN_LINE = re.compile(r"^  `(\w+)` ", re.M)
FOREIGN_KEY_LINE = re.compile(r"CONSTRAINT `fk_\w+` FOREIGN KEY")


def _columns_by_table(sql_text: str) -> dict[str, set[str]]:
    result: dict[str, set[str]] = {}
    for table, body in TABLE_BLOCK.findall(sql_text):
        result[table] = {name for name in COLUMN_LINE.findall(body + "\n")}
    return result


def test_schema_sql_is_in_sync_with_dbml():
    """schema.sql 必须能从当前 DBML 重新生成（--check 语义）。"""
    assert OUTPUT_PATH.exists(), "缺少 backend/db/schema.sql，请运行 python backend/db/generate_schema.py"
    generated = render(parse_dbml(DBML_PATH.read_text(encoding="utf-8")))
    assert OUTPUT_PATH.read_text(encoding="utf-8") == generated


def test_generated_ddl_shape():
    schema = parse_dbml(DBML_PATH.read_text(encoding="utf-8"))
    ddl = render(schema)
    columns = _columns_by_table(ddl)
    assert len(columns) == 28, "应生成 28 张表"
    assert len(FOREIGN_KEY_LINE.findall(ddl)) == 29, "应内联 29 条外键"
    # 外键内联 + CREATE TABLE IF NOT EXISTS => 整份 DDL 幂等（不含 ALTER TABLE ADD CONSTRAINT）
    assert "ALTER TABLE" not in ddl
    # MySQL 8 保留字列 row 必须加反引号
    assert "`row`" in ddl
    # 拓扑排序：被引用表必须先于引用表出现
    order = [table.name for table in order_tables(schema)]
    assert order.index("players") < order.index("player_settings")
    assert order.index("levels") < order.index("run_saves")
    assert order.index("sprite_sheets") < order.index("zombies")
    assert order.index("zombies") < order.index("level_wave_zombies")


def test_dbml_and_drawdb_json_describe_the_same_schema():
    """pvz_game.dbml 与 pvz_game.json 是同一套物理结构的两种表达，表 / 列必须一一对应。"""
    import json

    json_path = DBML_PATH.parent / "pvz_game.json"
    payload = json.loads(json_path.read_text(encoding="utf-8"))

    dbml_columns = {
        table.name: {column.name for column in table.columns}
        for table in parse_dbml(DBML_PATH.read_text(encoding="utf-8")).tables
    }
    json_columns = {
        table["name"]: {field["name"] for field in table.get("fields", [])}
        for table in payload["tables"]
    }

    assert set(json_columns) == set(dbml_columns), "DBML 与 JSON 的表集合不一致"
    for table in dbml_columns:
        assert json_columns[table] == dbml_columns[table], f"表 {table} 的列集合在 DBML 与 JSON 中不一致"


def _require_database():
    try:
        metadata = get_metadata()
    except Exception as error:  # noqa: BLE001
        pytest.skip(f"MySQL 不可用，跳过：{error}")
    return metadata


def test_live_database_matches_schema_sql():
    _require_database()
    expected = _columns_by_table(OUTPUT_PATH.read_text(encoding="utf-8"))
    engine = get_engine()

    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "select table_name, column_name from information_schema.columns "
                "where table_schema = database()"
            )
        ).all()
    actual: dict[str, set[str]] = {}
    for table_name, column_name in rows:
        actual.setdefault(table_name, set()).add(column_name)

    assert set(actual) == set(expected), "真实库的表集合与 schema.sql 不一致"
    for table, columns in expected.items():
        assert actual[table] == columns, f"表 {table} 的列集合与 schema.sql 不一致"

    with engine.connect() as conn:
        foreign_keys = conn.execute(
            text(
                "select count(*) from information_schema.table_constraints "
                "where constraint_schema = database() and constraint_type = 'FOREIGN KEY'"
            )
        ).scalar_one()
    assert int(foreign_keys) == 29


def test_live_database_tables_are_reflected():
    metadata = _require_database()
    assert len(metadata.tables) == 28
    for required in (
        "players", "player_settings", "player_progress", "player_level_progress",
        "run_saves", "run_save_cards", "run_save_card_cooldowns", "run_save_wave_states",
        "run_save_pending_spawns", "run_save_plants", "run_save_zombies", "run_save_mowers",
        "levels", "level_waves", "level_wave_zombies", "plants", "plant_behaviors",
        "zombies", "audio_tracks", "audio_config", "sprite_sheets", "sprite_frame_delays",
        "static_textures", "card_textures", "card_regions", "game_rules", "error_codes",
        "level_clear_events",
    ):
        assert required in metadata.tables, f"缺少表 {required}"
