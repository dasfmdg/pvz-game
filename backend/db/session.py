"""数据库连接与元数据反射（懒加载，进程内单例）。

DSN 来源优先级：环境变量 `PVZ_DB_DSN` > 默认本地实例。
默认值对齐本机便携实例：D:\\tools\\mysql-8.0.36-winx64 起的独立实例（端口 3307，库 pvz_game）。

表结构不在此处声明：由 `db.schema.sql` 建表后通过 SQLAlchemy 反射获得，
避免出现「代码里一份表结构 + DBML 里一份」的双份定义。
"""

from __future__ import annotations

import os

from sqlalchemy import MetaData, create_engine
from sqlalchemy.engine import Engine

DEFAULT_DSN = "mysql+pymysql://root@127.0.0.1:3307/pvz_game?charset=utf8mb4"

_engine: Engine | None = None
_metadata: MetaData | None = None


def get_dsn() -> str:
    return os.environ.get("PVZ_DB_DSN", DEFAULT_DSN)


def get_engine() -> Engine:
    """返回进程内共享的 Engine（pool_pre_ping 防止连接被服务端超时回收后复用失败）。"""
    global _engine
    if _engine is None:
        _engine = create_engine(get_dsn(), pool_pre_ping=True, pool_recycle=1800, future=True)
    return _engine


def get_metadata() -> MetaData:
    """反射真实库的表结构；失败即抛错（宁可启动失败，也不静默降级）。"""
    global _metadata
    if _metadata is None:
        metadata = MetaData()
        metadata.reflect(bind=get_engine())
        _metadata = metadata
    return _metadata


def dispose() -> None:
    """释放连接池与缓存（供测试与进程退出使用）。"""
    global _engine, _metadata
    if _engine is not None:
        _engine.dispose()
    _engine = None
    _metadata = None
