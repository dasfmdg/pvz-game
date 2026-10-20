"""从 `app.mock_data`（其来源是 game_config.gd）灌入静态数据与初始运行态。

幂等且**非破坏性**：
- 参考数据（关卡 / 植物 / 僵尸 / 资源 / 规则 / 错误码）按唯一键 upsert；
- 玩家数据（设置 / 进度 / 存档）只在缺失时创建（INSERT IGNORE / 仅初始化一次），
  重复执行 db_up 不会清空玩家已有进度与存档。
"""

from __future__ import annotations

from typing import Any

from sqlalchemy import MetaData, delete, insert, select
from sqlalchemy.dialects.mysql import insert as mysql_insert
from sqlalchemy.engine import Connection, Engine

from app import mock_data
from app.repositories.mysql_repository import LOCAL_PLAYER_UID, MySqlRepository

# ---- 通用 upsert ----
UPSERT_IGNORE = ("updated_at",)


def _upsert(conn: Connection, table: Any, rows: list[dict], update_columns: list[str]) -> None:
    if not rows:
        return
    statement = mysql_insert(table).values(rows)
    updates = {column: getattr(statement.inserted, column) for column in update_columns}
    conn.execute(statement.on_duplicate_key_update(**updates))


def _seed_levels(conn: Connection, metadata: MetaData) -> dict[str, int]:
    levels = metadata.tables["levels"]
    waves = metadata.tables["level_waves"]
    wave_zombies = metadata.tables["level_wave_zombies"]

    _upsert(
        conn,
        levels,
        [
            {
                "id": level["id"],
                "name": level["name"],
                "difficulty": level["difficulty"],
                "start_sun": level["start_sun"],
                "scene": level.get("scene", mock_data.SCENE_DAY),
            }
            for level in mock_data.LEVELS
        ],
        ["name", "difficulty", "start_sun", "scene"],
    )

    wave_rows: list[dict] = []
    for level in mock_data.LEVELS:
        for index, wave in enumerate(level["waves"]):
            wave_rows.append({
                "level_id": level["id"],
                "wave_index": index,
                "t": wave["t"],
                "huge": 1 if wave.get("huge") else 0,
            })
    _upsert(conn, waves, wave_rows, ["t", "huge"])

    wave_ids = {
        (int(row.level_id), int(row.wave_index)): int(row.id)
        for row in conn.execute(select(waves.c.id, waves.c.level_id, waves.c.wave_index)).all()
    }
    detail_rows: list[dict] = []
    for level in mock_data.LEVELS:
        for index, wave in enumerate(level["waves"]):
            wave_id = wave_ids[(level["id"], index)]
            for seq, zombie_id in enumerate(wave["z"]):
                detail_rows.append({"wave_id": wave_id, "seq": seq, "zombie_id": zombie_id})
    # 波次僵尸为纯明细，重建以保证与源数据一致（不承载玩家数据）
    conn.execute(delete(wave_zombies))
    if detail_rows:
        conn.execute(insert(wave_zombies), detail_rows)

    return {"levels": len(mock_data.LEVELS), "level_waves": len(wave_rows), "level_wave_zombies": len(detail_rows)}


def _seed_plants(conn: Connection, metadata: MetaData) -> dict[str, int]:
    plants = metadata.tables["plants"]
    behaviors = metadata.tables["plant_behaviors"]

    plant_rows = [
        {
            "id": plant_id,
            "name": mock_data.PLANTS_BY_ID[plant_id]["name"],
            "cost": mock_data.PLANTS_BY_ID[plant_id]["cost"],
            "hp": mock_data.PLANTS_BY_ID[plant_id]["hp"],
            "recharge": mock_data.PLANTS_BY_ID[plant_id]["recharge"],
            "unlock_level": mock_data.PLANT_UNLOCK.get(plant_id, 0),
            "card_order": order,
        }
        for order, plant_id in enumerate(mock_data.PLANT_ORDER)
    ]
    _upsert(conn, plants, plant_rows, ["name", "cost", "hp", "recharge", "unlock_level", "card_order"])

    behavior_rows = [
        {"plant_id": plant_id, "params": params}
        for plant_id, params in mock_data.PLANT_BEHAVIOR.items()
    ]
    _upsert(conn, behaviors, behavior_rows, ["params"])

    return {"plants": len(plant_rows), "plant_behaviors": len(behavior_rows)}


def _seed_zombies(conn: Connection, metadata: MetaData) -> dict[str, int]:
    table = metadata.tables["zombies"]
    # 各僵尸的专属列并不一致（如仅 flag 有 has_flag），统一补齐为全部列以保证批量插入列集一致
    columns = [column.name for column in table.columns if column.name != "updated_at"]
    rows = [{column: zombie.get(column) for column in columns} for zombie in mock_data.ZOMBIES]
    _upsert(
        conn,
        table,
        rows,
        ["name", "hp", "speed", "zw", "zh", "walk", "attack"],
    )
    return {"zombies": len(rows)}


def _seed_sprite_sheets(conn: Connection, metadata: MetaData) -> dict[str, int]:
    """精灵表必须最先写入：zombies.walk / zombies.attack 有指向 sprite_sheets.name 的外键。"""
    sheets = metadata.tables["sprite_sheets"]
    delays = metadata.tables["sprite_frame_delays"]

    sheet_rows = [
        {
            "name": sheet["name"],
            "w": sheet["w"],
            "h": sheet["h"],
            "frames": sheet["frames"],
            # d 与 delays 二选一：无统一帧时长的精灵表此列留 NULL（补齐键以保证批量插入列集一致）
            "d": sheet.get("d"),
            "src": sheet["src"],
        }
        for sheet in mock_data.SHEETS
    ]
    _upsert(conn, sheets, sheet_rows, ["w", "h", "frames", "d", "src"])

    delay_rows: list[dict] = []
    for sheet in mock_data.SHEETS:
        for index, seconds in enumerate(sheet.get("delays", [])):
            delay_rows.append({"sheet_name": sheet["name"], "frame_index": index, "delay_seconds": seconds})
    conn.execute(delete(delays))
    if delay_rows:
        conn.execute(insert(delays), delay_rows)

    return {"sprite_sheets": len(sheet_rows), "sprite_frame_delays": len(delay_rows)}


def _seed_audio_and_textures(conn: Connection, metadata: MetaData) -> dict[str, int]:
    """音频与贴图：card_textures / card_regions 依赖 plants，故在 plants 之后执行。"""
    tracks = metadata.tables["audio_tracks"]
    config = metadata.tables["audio_config"]
    static = metadata.tables["static_textures"]
    cards = metadata.tables["card_textures"]
    regions = metadata.tables["card_regions"]

    track_rows = [{"name": "background", "kind": "bgm", "path": mock_data.BGM_PATH}]
    track_rows += [{"name": item["name"], "kind": "sfx", "path": item["path"]} for item in mock_data.SOUNDS]
    _upsert(conn, tracks, track_rows, ["kind", "path"])

    _upsert(
        conn,
        config,
        [{
            "id": 1,
            "pool_size": mock_data.SOUND_POOL_SIZE,
            "sfx_volume_db": mock_data.SFX_VOLUME_DB,
            "bgm_volume_db": mock_data.BGM_VOLUME_DB,
        }],
        ["pool_size", "sfx_volume_db", "bgm_volume_db"],
    )

    _upsert(conn, static, [{"name": item["name"], "path": item["path"]} for item in mock_data.STATIC_TEXTURES], ["path"])
    _upsert(conn, cards, [{"plant_id": item["name"], "path": item["path"]} for item in mock_data.CARD_TEXTURES], ["path"])
    _upsert(
        conn,
        regions,
        [
            {"plant_id": item["name"], "x": item["x"], "y": item["y"], "w": item["w"], "h": item["h"]}
            for item in mock_data.CARD_REGIONS
        ],
        ["x", "y", "w", "h"],
    )

    return {
        "audio_tracks": len(track_rows),
        "audio_config": 1,
        "static_textures": len(mock_data.STATIC_TEXTURES),
        "card_textures": len(mock_data.CARD_TEXTURES),
        "card_regions": len(mock_data.CARD_REGIONS),
    }


def _seed_rules_and_errors(conn: Connection, metadata: MetaData) -> dict[str, int]:
    rules = metadata.tables["game_rules"]
    errors = metadata.tables["error_codes"]

    # 单例行只插 id，其余列取 DBML 中声明的默认值（= 源码常量），避免在代码里复制第二份常量表
    _upsert(conn, rules, [{"id": 1}], ["id"])

    error_rows = [
        {"code": code, "http_status": status, "default_msg": message, "description": description}
        for code, status, message, description in mock_data.ERROR_CODE_ROWS
    ]
    _upsert(conn, errors, error_rows, ["http_status", "default_msg", "description"])

    return {"game_rules": 1, "error_codes": len(error_rows)}


def _seed_initial_player(engine: Engine, repository: MySqlRepository) -> dict[str, int]:
    """初始运行态：单机玩家 + 契约示例中的设置 / 进度 / 槽位 1 快照。

    只在数据缺失时写入，重复执行不会覆盖玩家后续产生的进度与存档。
    """
    with engine.begin() as conn:
        repository.ensure_player(conn)

    created = 0
    current = repository.get_progress()
    if current["unlocked_level"] == 0 and not current["levels"]:
        repository.put_progress(mock_data.INITIAL_PROGRESS)
        created += 1

    if repository.get_slot(mock_data.INITIAL_SAVE_SLOT) is None:
        repository.put_slot(
            mock_data.INITIAL_SAVE_SLOT,
            mock_data.INITIAL_SNAPSHOT,
            mock_data.INITIAL_SAVE_SAVED_AT,
        )
        created += 1

    return {"player": 1, "initial_state_written": created}


def seed(engine: Engine, metadata: MetaData, repository: MySqlRepository) -> dict[str, int]:
    """按外键依赖顺序灌数（顺序错误会直接触发 FK 约束失败，因此顺序即契约）。"""
    counts: dict[str, int] = {}
    with engine.begin() as conn:
        counts.update(_seed_rules_and_errors(conn, metadata))      # 无依赖
        counts.update(_seed_sprite_sheets(conn, metadata))         # 无依赖（zombies 依赖它）
        counts.update(_seed_plants(conn, metadata))                # 无依赖
        counts.update(_seed_zombies(conn, metadata))               # 依赖 sprite_sheets
        counts.update(_seed_audio_and_textures(conn, metadata))    # 依赖 plants
        counts.update(_seed_levels(conn, metadata))                # 依赖 zombies（波次明细）
    counts.update(_seed_initial_player(engine, repository))
    return counts
