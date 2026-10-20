"""应用入口：CORS、路由挂载（统一 /api 前缀）、统一异常处理、结构化日志。"""

import logging
import os
from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .errors import register_exception_handlers
from .routers import almanac, levels, overview, progress, resources, saves, settings

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

logger = logging.getLogger("pvz.main")

API_PREFIX = "/api"


def _log_active_store() -> None:
    """启动时打印当前存储后端，避免"以为连的是库、其实跑的是内存态"这类误判。"""
    from .repositories import get_repository
    from .repositories.memory_repository import MemoryRepository

    repository = get_repository()
    kind = "memory" if isinstance(repository, MemoryRepository) else "mysql"
    dsn = os.environ.get("PVZ_DB_DSN", "") if kind == "mysql" else ""
    logger.info("[启动] 存储后端 PVZ_STORE=%s%s", kind, f" DSN={dsn}" if dsn else "")


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    _log_active_store()
    yield


app = FastAPI(
    title="植物大战僵尸 · Godot 版（pvz-game）后端",
    version="1.0.0",
    description="按 pvz-game 工程真实数据模型实现的 Mock 后端，契约见 openapi.yaml。",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

register_exception_handlers(app)

for module in (overview, settings, progress, saves, levels, almanac, resources):
    app.include_router(module.router, prefix=API_PREFIX)
