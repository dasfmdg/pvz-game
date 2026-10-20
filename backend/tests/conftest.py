"""pytest 公共夹具。

- 默认把 `PVZ_STORE` 设为 `memory`：既有 150 项契约/集成测试无需数据库即可跑；
  需要验证 MySQL 后端的用例自行 monkeypatch 成 `mysql`（见 tests/test_repository_mysql.py）。
- reset_server_state：每个用例前后把内存态复位到出厂值（store.state 是模块级单例）。
"""

import os

os.environ.setdefault("PVZ_STORE", "memory")

import pytest
from fastapi.testclient import TestClient

from app import store
from app.main import app


@pytest.fixture(autouse=True)
def reset_server_state():
    store.state.__init__()
    yield
    store.state.__init__()


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client
