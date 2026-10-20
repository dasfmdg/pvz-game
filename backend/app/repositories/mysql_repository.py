"""MySQL 仓储：真实库实现（SQLAlchemy Core + 反射）。

表结构不在代码里重复声明：列定义全部来自 `db.session.get_metadata()` 的反射结果，
而反射结果又来自 `backend/db/schema.sql`（由 pvz_game.dbml 生成）。
因此「DBML → schema.sql → 真实库 → 代码」是一条单向链路，不存在第二份 schema 定义。

契约对齐要点：
- 输出字段严格投影为 openapi.yaml 的 schema（DB 里的 bookkeeping 列如 created_at / card_order 不下发）；
- 可空列在值为 NULL 时不输出该键，与内存后端（mock_data 里不含该键）行为一致。
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import delete, insert, select, update
from sqlalchemy.dialects.mysql import insert as mysql_insert
from sqlalchemy.engine import Connection
from sqlalchemy.sql import func

from db.session import get_engine, get_metadata
from app.repositories.base import (
    Repository,
    derive_available_plants,
    derive_seed_slot_limit,
    derive_zombies_for_level,
)

LOCAL_PLAYER_UID = "local"


def _to_float(value: Any) -> float | None:
    return None if value is None else float(value)


def _to_int(value: Any) -> int | None:
    return None if value is None else int(value)


def _insert_ignore(conn: Connection, table: Any, values: dict[str, Any]) -> None:
    """幂等插入：存在同键行时跳过（MySQL INSERT IGNORE），绝不覆盖既有数据。"""
    conn.execute(mysql_insert(table).values(**values).prefix_with("IGNORE"))


class MySqlRepository(Repository):
    def __init__(self) -> None:
        self._engine = get_engine()
        self._metadata = get_metadata()

    def _table(self, name: str) -> Any:
        try:
            return self._metadata.tables[name]
        except KeyError as error:  # 库未初始化时给出可执行的下一步
            raise RuntimeError(
                f"数据表 {name} 不存在：请先运行 `python backend/scripts/db_up.py` 建库并灌初始数据"
            ) from error

    # ---------------- 边界常量（来源：game_rules 单行） ----------------
    def _rules_row(self, conn: Connection) -> Any:
        rules = self._table("game_rules")
        row = conn.execute(select(rules).where(rules.c.id == 1)).one_or_none()
        if row is None:
            raise RuntimeError("game_rules 缺少单例行（id=1）：请先运行 `python backend/scripts/db_up.py`")
        return row

    @property
    def slot_min(self) -> int:
        with self._engine.connect() as conn:
            return int(self._rules_row(conn).run_slot_min)

    @property
    def slot_max(self) -> int:
        with self._engine.connect() as conn:
            return int(self._rules_row(conn).run_slot_max)

    @property
    def max_level_index(self) -> int:
        with self._engine.connect() as conn:
            return int(self._rules_row(conn).total_levels) - 1

    def _derive_rules(self, conn: Connection) -> dict[str, int]:
        row = self._rules_row(conn)
        return {
            "seed_slot_base": int(row.seed_slot_base),
            "seed_slot_step": int(row.seed_slot_step),
            "seed_slot_max": int(row.seed_slot_max),
        }

    def _seed_select_from_level(self, conn: Connection) -> int:
        return int(self._rules_row(conn).seed_select_from_level)

    # ---------------- 玩家（单机维度，无鉴权） ----------------
    def ensure_player(self, conn: Connection) -> int:
        """幂等确保单机玩家及其设置 / 总进度行存在；已存在则不覆盖。"""
        players = self._table("players")
        settings = self._table("player_settings")
        progress = self._table("player_progress")

        _insert_ignore(conn, players, {"player_uid": LOCAL_PLAYER_UID})
        player_id = conn.execute(
            select(players.c.id).where(players.c.player_uid == LOCAL_PLAYER_UID)
        ).scalar_one()
        _insert_ignore(conn, settings, {"player_id": player_id})
        _insert_ignore(conn, progress, {"player_id": player_id})
        return int(player_id)

    def _player_id(self, conn: Connection) -> int:
        players = self._table("players")
        found = conn.execute(
            select(players.c.id).where(players.c.player_uid == LOCAL_PLAYER_UID)
        ).scalar_one_or_none()
        if found is None:
            found = self.ensure_player(conn)
        return int(found)

    # ---------------- 概览 ----------------
    def overview(self) -> tuple[dict, int, int]:
        progress = self.get_progress()
        cleared = sum(1 for entry in progress["levels"].values() if entry.get("cleared"))
        total_kills = sum(int(entry.get("best_kills", 0)) for entry in progress["levels"].values())
        return progress, cleared, total_kills

    # ---------------- 设置 ----------------
    def get_settings(self) -> dict:
        settings = self._table("player_settings")
        with self._engine.begin() as conn:
            player_id = self._player_id(conn)
            row = conn.execute(select(settings).where(settings.c.player_id == player_id)).one()
        return {
            "bgm_volume": float(row.bgm_volume),
            "sfx_volume": float(row.sfx_volume),
            "muted": bool(row.muted),
        }

    def put_settings(self, settings: dict) -> dict:
        table = self._table("player_settings")
        with self._engine.begin() as conn:
            player_id = self._player_id(conn)
            conn.execute(
                update(table)
                .where(table.c.player_id == player_id)
                .values(
                    bgm_volume=settings["bgm_volume"],
                    sfx_volume=settings["sfx_volume"],
                    muted=1 if settings["muted"] else 0,
                    updated_at=func.current_timestamp(),
                )
            )
        return self.get_settings()

    # ---------------- 进度 ----------------
    def get_progress(self) -> dict:
        total = self._table("player_progress")
        level_table = self._table("player_level_progress")
        with self._engine.begin() as conn:
            player_id = self._player_id(conn)
            unlocked = conn.execute(
                select(total.c.unlocked_level).where(total.c.player_id == player_id)
            ).scalar_one()
            rows = conn.execute(
                select(level_table.c.level_index, level_table.c.cleared, level_table.c.best_kills)
                .where(level_table.c.player_id == player_id)
                .order_by(level_table.c.level_index)
            ).all()
        levels = {
            str(int(row.level_index)): {"cleared": bool(row.cleared), "best_kills": int(row.best_kills)}
            for row in rows
        }
        return {"unlocked_level": int(unlocked), "levels": levels}

    def put_progress(self, progress: dict) -> dict:
        total = self._table("player_progress")
        level_table = self._table("player_level_progress")
        with self._engine.begin() as conn:
            player_id = self._player_id(conn)
            conn.execute(
                update(total)
                .where(total.c.player_id == player_id)
                .values(unlocked_level=progress["unlocked_level"], updated_at=func.current_timestamp())
            )
            conn.execute(delete(level_table).where(level_table.c.player_id == player_id))
            rows = [
                {
                    "player_id": player_id,
                    "level_index": int(key),
                    "cleared": 1 if value["cleared"] else 0,
                    "best_kills": int(value["best_kills"]),
                }
                for key, value in progress["levels"].items()
            ]
            if rows:
                conn.execute(insert(level_table), rows)
        return self.get_progress()

    def clear_level(self, index: int, kills: int) -> tuple[int, dict]:
        total = self._table("player_progress")
        level_table = self._table("player_level_progress")
        events = self._table("level_clear_events")
        with self._engine.begin() as conn:
            player_id = self._player_id(conn)
            existing = conn.execute(
                select(level_table.c.best_kills, level_table.c.cleared)
                .where(level_table.c.player_id == player_id, level_table.c.level_index == index)
            ).one_or_none()
            best_kills = max(int(existing.best_kills), kills) if existing is not None else kills
            if existing is None:
                conn.execute(
                    insert(level_table).values(
                        player_id=player_id, level_index=index, cleared=1, best_kills=best_kills
                    )
                )
            else:
                conn.execute(
                    update(level_table)
                    .where(level_table.c.player_id == player_id, level_table.c.level_index == index)
                    .values(cleared=1, best_kills=best_kills, updated_at=func.current_timestamp())
                )
            current = conn.execute(
                select(total.c.unlocked_level).where(total.c.player_id == player_id)
            ).scalar_one()
            unlocked = min(max(int(current), index + 1), self.max_level_index)
            conn.execute(
                update(total)
                .where(total.c.player_id == player_id)
                .values(unlocked_level=unlocked, updated_at=func.current_timestamp())
            )
            conn.execute(
                insert(events).values(player_id=player_id, level_index=index, kills=kills)
            )
        return unlocked, {"cleared": True, "best_kills": best_kills}

    # ---------------- 存档（单局快照） ----------------
    def _slot_summary(self, conn: Connection, player_id: int, slot: int) -> dict:
        saves = self._table("run_saves")
        levels = self._table("levels")
        row = conn.execute(
            select(saves).where(saves.c.player_id == player_id, saves.c.slot == slot)
        ).one_or_none()
        if row is None:
            return {"slot": slot, "empty": True}
        return {
            "slot": slot,
            "level_index": int(row.level_index),
            "level_name": row.level_name,
            "time": float(row.time),
            "sun": int(row.sun),
            "killed": int(row.killed),
            "saved_at": row.saved_at.strftime("%Y-%m-%dT%H:%M:%S"),
        }

    def list_slots(self) -> list[dict]:
        with self._engine.begin() as conn:
            player_id = self._player_id(conn)
            return [self._slot_summary(conn, player_id, slot) for slot in range(self.slot_min, self.slot_max + 1)]

    def latest_save(self) -> dict | None:
        with self._engine.begin() as conn:
            player_id = self._player_id(conn)
            summaries = [
                self._slot_summary(conn, player_id, slot)
                for slot in range(self.slot_min, self.slot_max + 1)
            ]
        present = [summary for summary in summaries if not summary.get("empty")]
        if not present:
            return None
        return max(present, key=lambda item: item["saved_at"])

    def get_slot(self, slot: int) -> dict | None:
        with self._engine.begin() as conn:
            player_id = self._player_id(conn)
            return self._read_snapshot(conn, player_id, slot)

    def put_slot(self, slot: int, snapshot: dict, saved_at: str) -> str:
        with self._engine.begin() as conn:
            player_id = self._player_id(conn)
            self._write_snapshot(conn, player_id, slot, snapshot, saved_at)
        return saved_at

    def delete_slot(self, slot: int) -> bool:
        with self._engine.begin() as conn:
            player_id = self._player_id(conn)
            return self._delete_slot(conn, player_id, slot)

    # ---- 快照读写（run_saves + 7 张子表） ----
    def _delete_slot(self, conn: Connection, player_id: int, slot: int) -> bool:
        saves = self._table("run_saves")
        row = conn.execute(
            select(saves.c.id).where(saves.c.player_id == player_id, saves.c.slot == slot)
        ).one_or_none()
        if row is None:
            return False
        save_id = int(row.id)
        for name in (
            "run_save_cards",
            "run_save_card_cooldowns",
            "run_save_pending_spawns",
            "run_save_plants",
            "run_save_zombies",
            "run_save_mowers",
            "run_save_wave_states",
        ):
            table = self._table(name)
            if name == "run_save_pending_spawns":
                wave_states = self._table("run_save_wave_states")
                state_ids = conn.execute(
                    select(wave_states.c.id).where(wave_states.c.save_id == save_id)
                ).scalars().all()
                if state_ids:
                    conn.execute(delete(table).where(table.c.wave_state_id.in_(state_ids)))
                continue
            conn.execute(delete(table).where(table.c.save_id == save_id))
        conn.execute(delete(saves).where(saves.c.id == save_id))
        return True

    def _write_snapshot(
        self, conn: Connection, player_id: int, slot: int, snapshot: dict, saved_at: str
    ) -> None:
        self._delete_slot(conn, player_id, slot)
        saves = self._table("run_saves")
        levels = self._table("levels")
        level_index = int(snapshot["level_index"])
        level_name = conn.execute(select(levels.c.name).where(levels.c.id == level_index)).scalar_one_or_none()
        wave = snapshot["wave"]
        conn.execute(
            insert(saves).values(
                player_id=player_id,
                slot=slot,
                snapshot_version=int(snapshot["version"]),
                level_index=level_index,
                level_name=level_name or "",
                time=snapshot["time"],
                sun=int(snapshot["sun"]),
                killed=int(snapshot["killed"]),
                sky_sun_timer=snapshot.get("sky_sun_timer") or 0,
                saved_at=saved_at,
            )
        )
        save_id = int(conn.execute(
            select(saves.c.id).where(saves.c.player_id == player_id, saves.c.slot == slot)
        ).scalar_one())

        cards = snapshot.get("level_plants") or []
        if cards:
            conn.execute(
                insert(self._table("run_save_cards")),
                [{"save_id": save_id, "seq": seq, "plant_id": plant_id} for seq, plant_id in enumerate(cards)],
            )

        cooldowns = snapshot.get("card_cooldowns") or {}
        if cooldowns:
            conn.execute(
                insert(self._table("run_save_card_cooldowns")),
                [
                    {"save_id": save_id, "plant_id": plant_id, "cooldown_seconds": seconds}
                    for plant_id, seconds in cooldowns.items()
                ],
            )

        wave_states = self._table("run_save_wave_states")
        conn.execute(
            insert(wave_states).values(
                save_id=save_id,
                wave_index=int(wave["index"]),
                early_trigger_at=wave["early_trigger_at"],
                lane_cursor=int(wave["lane_cursor"]),
            )
        )
        wave_state_id = int(conn.execute(
            select(wave_states.c.id).where(wave_states.c.save_id == save_id)
        ).scalar_one())
        pending = wave.get("pending") or []
        if pending:
            conn.execute(
                insert(self._table("run_save_pending_spawns")),
                [
                    {"wave_state_id": wave_state_id, "seq": seq, "dt": item["dt"], "zombie_id": item["type"]}
                    for seq, item in enumerate(pending)
                ],
            )

        plants = snapshot.get("plants") or []
        if plants:
            conn.execute(
                insert(self._table("run_save_plants")),
                [
                    {
                        "save_id": save_id,
                        "seq": seq,
                        "plant_id": item["type"],
                        "col": int(item["col"]),
                        "row": int(item["row"]),
                        "hp": int(item["hp"]),
                        "state": item.get("state") or {},
                    }
                    for seq, item in enumerate(plants)
                ],
            )

        zombies = snapshot.get("zombies") or []
        if zombies:
            conn.execute(
                insert(self._table("run_save_zombies")),
                [
                    {
                        "save_id": save_id,
                        "seq": seq,
                        "zombie_id": item["type"],
                        "row": int(item["row"]),
                        "x": item["x"],
                        "hp": int(item["hp"]),
                        "has_hat": 1 if item["has_hat"] else 0,
                        "hat_hp": int(item["hat_hp"]),
                        "state": int(item["state"]),
                        "slow_t": item["slow_t"],
                        "bite_t": item["bite_t"],
                    }
                    for seq, item in enumerate(zombies)
                ],
            )

        mowers = snapshot.get("mowers") or []
        if mowers:
            conn.execute(
                insert(self._table("run_save_mowers")),
                [
                    {
                        "save_id": save_id,
                        "row": int(item["row"]),
                        "used": 1 if item["used"] else 0,
                        "running": 1 if item["running"] else 0,
                        "x": item["x"],
                    }
                    for item in mowers
                ],
            )

    def _read_snapshot(self, conn: Connection, player_id: int, slot: int) -> dict | None:
        saves = self._table("run_saves")
        save = conn.execute(
            select(saves).where(saves.c.player_id == player_id, saves.c.slot == slot)
        ).one_or_none()
        if save is None:
            return None
        save_id = int(save.id)

        cards = self._table("run_save_cards")
        level_plants = conn.execute(
            select(cards.c.plant_id).where(cards.c.save_id == save_id).order_by(cards.c.seq)
        ).scalars().all()

        cooldown_table = self._table("run_save_card_cooldowns")
        cooldown_rows = conn.execute(
            select(cooldown_table.c.plant_id, cooldown_table.c.cooldown_seconds).where(
                cooldown_table.c.save_id == save_id
            )
        ).all()
        card_cooldowns = {row.plant_id: float(row.cooldown_seconds) for row in cooldown_rows}

        wave_states = self._table("run_save_wave_states")
        wave = conn.execute(
            select(wave_states).where(wave_states.c.save_id == save_id)
        ).one_or_none()
        pending: list[dict] = []
        if wave is not None:
            pending_table = self._table("run_save_pending_spawns")
            pending = [
                {"dt": float(row.dt), "type": row.zombie_id}
                for row in conn.execute(
                    select(pending_table.c.dt, pending_table.c.zombie_id)
                    .where(pending_table.c.wave_state_id == int(wave.id))
                    .order_by(pending_table.c.seq)
                ).all()
            ]

        plants_table = self._table("run_save_plants")
        plants = [
            {
                "type": row.plant_id,
                "col": int(row.col),
                "row": int(row.row),
                "hp": int(row.hp),
                "state": row.state or {},
            }
            for row in conn.execute(
                select(plants_table).where(plants_table.c.save_id == save_id).order_by(plants_table.c.seq)
            ).all()
        ]

        zombies_table = self._table("run_save_zombies")
        zombies = [
            {
                "type": row.zombie_id,
                "row": int(row.row),
                "x": float(row.x),
                "hp": int(row.hp),
                "has_hat": bool(row.has_hat),
                "hat_hp": int(row.hat_hp),
                "state": int(row.state),
                "slow_t": float(row.slow_t),
                "bite_t": float(row.bite_t),
            }
            for row in conn.execute(
                select(zombies_table).where(zombies_table.c.save_id == save_id).order_by(zombies_table.c.seq)
            ).all()
        ]

        mowers_table = self._table("run_save_mowers")
        mowers = [
            {"row": int(row.row), "used": bool(row.used), "running": bool(row.running), "x": float(row.x)}
            for row in conn.execute(
                select(mowers_table).where(mowers_table.c.save_id == save_id).order_by(mowers_table.c.row)
            ).all()
        ]

        snapshot: dict[str, Any] = {
            "version": int(save.snapshot_version),
            "level_index": int(save.level_index),
            "level_plants": list(level_plants),
            "time": float(save.time),
            "sun": int(save.sun),
            "killed": int(save.killed),
        }
        if save.sky_sun_timer is not None:
            snapshot["sky_sun_timer"] = float(save.sky_sun_timer)
        snapshot["wave"] = {
            "index": int(wave.wave_index) if wave is not None else 0,
            "early_trigger_at": float(wave.early_trigger_at) if wave is not None else -1.0,
            "lane_cursor": int(wave.lane_cursor) if wave is not None else 0,
            "pending": pending,
        }
        if card_cooldowns:
            snapshot["card_cooldowns"] = card_cooldowns
        snapshot["plants"] = plants
        snapshot["zombies"] = zombies
        snapshot["mowers"] = mowers
        return {"saved_at": save.saved_at.strftime("%Y-%m-%dT%H:%M:%S"), "snapshot": snapshot}

    # ---------------- 关卡元数据 ----------------
    def _level_waves(self, conn: Connection, level_id: int) -> list[dict]:
        waves = self._table("level_waves")
        zombie_table = self._table("level_wave_zombies")
        rows = conn.execute(
            select(waves.c.id, waves.c.wave_index, waves.c.t.label("wave_t"), waves.c.huge)
            .where(waves.c.level_id == level_id)
            .order_by(waves.c.wave_index)
        ).all()
        result: list[dict] = []
        for row in rows:
            kinds = conn.execute(
                select(zombie_table.c.zombie_id)
                .where(zombie_table.c.wave_id == int(row.id))
                .order_by(zombie_table.c.seq)
            ).scalars().all()
            # 列名 t 需走别名取值：SQLAlchemy 2.1 起 Row 行为贴近元组，row.t 会命中元组属性
            wave: dict[str, Any] = {"t": float(row.wave_t), "z": list(kinds)}
            if row.huge:
                wave["huge"] = True
            result.append(wave)
        return result

    def _plant_order_and_unlock(self, conn: Connection) -> tuple[list[str], dict[str, int]]:
        plants = self._table("plants")
        rows = conn.execute(
            select(plants.c.id, plants.c.unlock_level).order_by(plants.c.card_order)
        ).all()
        return [row.id for row in rows], {row.id: int(row.unlock_level) for row in rows}

    def _available_plants(self, conn: Connection, index: int) -> list[str]:
        order, unlock = self._plant_order_and_unlock(conn)
        return derive_available_plants(order, unlock, index + 1)

    def _zombie_ids(self, conn: Connection) -> set[str]:
        zombies = self._table("zombies")
        return set(conn.execute(select(zombies.c.id)).scalars().all())

    def list_levels(self) -> list[dict]:
        levels = self._table("levels")
        progress = self.get_progress()
        unlocked_level = progress["unlocked_level"]
        entries = progress["levels"]
        with self._engine.begin() as conn:
            rows = conn.execute(
                select(levels.c.id, levels.c.name, levels.c.difficulty, levels.c.start_sun, levels.c.scene)
                .order_by(levels.c.id)
            ).all()
        result = []
        for row in rows:
            record = entries.get(str(int(row.id)), {})
            result.append({
                "id": int(row.id),
                "name": row.name,
                "difficulty": int(row.difficulty),
                "start_sun": int(row.start_sun),
                "scene": row.scene,
                "cleared": bool(record.get("cleared", False)),
                "best_kills": int(record.get("best_kills", 0)),
                "unlocked": int(row.id) <= unlocked_level,
            })
        return result

    def get_level(self, index: int) -> dict | None:
        levels = self._table("levels")
        with self._engine.begin() as conn:
            row = conn.execute(select(levels).where(levels.c.id == index)).one_or_none()
            if row is None:
                return None
            waves = self._level_waves(conn, index)
            plants = self._available_plants(conn, index)
            rules = self._derive_rules(conn)
            threshold = self._seed_select_from_level(conn)
            known = self._zombie_ids(conn)
        return {
            "id": int(row.id),
            "name": row.name,
            "difficulty": int(row.difficulty),
            "start_sun": int(row.start_sun),
            "scene": row.scene,
            "waves": waves,
            "available_plants": plants,
            "seed_slot_limit": derive_seed_slot_limit(len(plants), index + 1, rules),
            "needs_seed_select": index + 1 >= threshold,
            "zombies": derive_zombies_for_level(waves, known),
        }

    def get_level_plants(self, index: int) -> list[str] | None:
        levels = self._table("levels")
        with self._engine.begin() as conn:
            exists = conn.execute(select(levels.c.id).where(levels.c.id == index)).scalar_one_or_none()
            if exists is None:
                return None
            return self._available_plants(conn, index)

    # ---------------- 图鉴 ----------------
    def list_plants(self) -> list[dict]:
        plants = self._table("plants")
        with self._engine.begin() as conn:
            rows = conn.execute(select(plants).order_by(plants.c.card_order)).all()
        return [
            {
                "id": row.id,
                "name": row.name,
                "cost": int(row.cost),
                "hp": int(row.hp),
                "recharge": float(row.recharge),
                "unlock_level": int(row.unlock_level),
            }
            for row in rows
        ]

    _ZOMBIE_OPTIONAL_TEXT = ("dirty_walk", "dirty_attack", "hat_removed_walk", "hat_removed_attack", "jump", "after_jump_walk", "rip")
    _ZOMBIE_OPTIONAL_FLOAT = ("dirt_ratio", "hat_ratio", "hat_removed_speed")

    def _zombie_dict(self, row: Any) -> dict:
        data: dict[str, Any] = {
            "id": row.id,
            "name": row.name,
            "hp": int(row.hp),
            "speed": float(row.speed),
            "zw": float(row.zw),
            "zh": float(row.zh),
            "walk": row.walk,
            "attack": row.attack,
        }
        for name in self._ZOMBIE_OPTIONAL_TEXT:
            value = getattr(row, name)
            if value is not None:
                data[name] = value
        for name in self._ZOMBIE_OPTIONAL_FLOAT:
            value = getattr(row, name)
            if value is not None:
                data[name] = float(value)
        if row.hat_hp is not None:
            data["hat_hp"] = int(row.hat_hp)
        if row.has_flag is not None:
            data["has_flag"] = bool(row.has_flag)
        return data

    def list_zombies(self) -> list[dict]:
        zombies = self._table("zombies")
        with self._engine.begin() as conn:
            # 按 sort_order 输出：与内置默认数据的 ZOMBIES 声明顺序一致（契约「对齐 GameConfig.ZOMBIES」）
            rows = conn.execute(select(zombies).order_by(zombies.c.sort_order)).all()
        return [self._zombie_dict(row) for row in rows]

    def get_zombie(self, zombie_id: str) -> dict | None:
        zombies = self._table("zombies")
        with self._engine.begin() as conn:
            row = conn.execute(select(zombies).where(zombies.c.id == zombie_id)).one_or_none()
        return None if row is None else self._zombie_dict(row)

    # ---------------- 资源 ----------------
    def get_audio(self) -> dict:
        tracks = self._table("audio_tracks")
        config = self._table("audio_config")
        with self._engine.begin() as conn:
            rows = conn.execute(select(tracks).order_by(tracks.c.id)).all()
            cfg = conn.execute(select(config).where(config.c.id == 1)).one_or_none()
        if cfg is None:
            raise RuntimeError("audio_config 缺少单例行（id=1）：请先运行 `python backend/scripts/db_up.py`")
        bgm = next((row for row in rows if row.kind == "bgm"), None)
        if bgm is None:
            raise RuntimeError("audio_tracks 缺少 kind=bgm 的记录：请先运行 `python backend/scripts/db_up.py`")
        return {
            "bgm": {"name": bgm.name, "path": bgm.path},
            "sfx": [{"name": row.name, "path": row.path} for row in rows if row.kind == "sfx"],
            "pool_size": int(cfg.pool_size),
            "sfx_volume_db": float(cfg.sfx_volume_db),
            "bgm_volume_db": float(cfg.bgm_volume_db),
        }

    def get_sprites(self) -> dict:
        sheets = self._table("sprite_sheets")
        delays = self._table("sprite_frame_delays")
        static = self._table("static_textures")
        cards = self._table("card_textures")
        regions = self._table("card_regions")
        with self._engine.begin() as conn:
            # 按 sort_order 输出：与内置默认数据的 SHEETS 声明顺序一致
            sheet_rows = conn.execute(select(sheets).order_by(sheets.c.sort_order)).all()
            delay_rows = conn.execute(
                select(delays).order_by(delays.c.sheet_name, delays.c.frame_index)
            ).all()
            static_rows = conn.execute(select(static).order_by(static.c.id)).all()
            card_rows = conn.execute(select(cards).order_by(cards.c.id)).all()
            region_rows = conn.execute(select(regions).order_by(regions.c.id)).all()

        grouped: dict[str, list[float]] = {}
        for row in delay_rows:
            grouped.setdefault(row.sheet_name, []).append(float(row.delay_seconds))

        sheet_dicts: list[dict] = []
        for row in sheet_rows:
            item: dict[str, Any] = {
                "name": row.name,
                "w": int(row.w),
                "h": int(row.h),
                "frames": int(row.frames),
            }
            # d 与 delays 二选一：单独维护 delays 的精灵表不再下发 d（与内置默认数据一致）
            if row.name in grouped:
                item["delays"] = grouped[row.name]
            elif row.d is not None:
                item["d"] = float(row.d)
            item["src"] = row.src
            sheet_dicts.append(item)

        return {
            "sheets": sheet_dicts,
            "static_textures": [{"name": row.name, "path": row.path} for row in static_rows],
            "card_textures": [{"name": row.plant_id, "path": row.path} for row in card_rows],
            "card_regions": [
                {
                    "name": row.plant_id,
                    "x": float(row.x),
                    "y": float(row.y),
                    "w": float(row.w),
                    "h": float(row.h),
                }
                for row in region_rows
            ],
        }
