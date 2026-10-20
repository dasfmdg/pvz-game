"""仓储工厂：按 `PVZ_STORE` 环境变量选择后端（默认 mysql，可切 memory 降级）。

之所以保留双后端：没有 MySQL 的环境（如纯 CI 或本地快速跑）仍能完整验证契约；
MySQL 后端与内存后端共用 `base.py` 的派生公式，行为一致性由同一套测试约束。
"""

from __future__ import annotations

import os

from .base import Repository

_memory: Repository | None = None
_mysql: Repository | None = None


def get_repository() -> Repository:
    kind = os.environ.get("PVZ_STORE", "mysql").strip().lower()
    if kind == "memory":
        return _memory_repository()
    if kind == "mysql":
        return _mysql_repository()
    raise ValueError(f"未知的 PVZ_STORE 取值：{kind!r}（可选 mysql / memory）")


def _memory_repository() -> Repository:
    global _memory
    if _memory is None:
        from .memory_repository import MemoryRepository

        _memory = MemoryRepository()
    return _memory


def _mysql_repository() -> Repository:
    global _mysql
    if _mysql is None:
        from .mysql_repository import MySqlRepository

        _mysql = MySqlRepository()
    return _mysql


def reset_repository() -> None:
    """清空单例（供测试在切换 PVZ_STORE 后重新取用）。"""
    global _memory, _mysql
    _memory = None
    _mysql = None
