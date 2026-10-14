"""应用入口：CORS、路由挂载（统一 /api 前缀）、统一异常处理、结构化日志。"""

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .errors import register_exception_handlers
from .routers import almanac, levels, overview, progress, resources, saves, settings

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

API_PREFIX = "/api"

app = FastAPI(
    title="植物大战僵尸 · Godot 版（pvz-game）后端",
    version="1.0.0",
    description="按 pvz-game 工程真实数据模型整理的 Mock 后端，契约见 openapi.yaml。",
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
