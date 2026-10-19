"""pytest 公共夹具。

- reset_server_state：每个用例前后把进程内可变状态（settings / progress / saves）
  复位到出厂初始值，保证用例之间零串扰（store.state 是模块级单例，路由按引用持有）。
- client：FastAPI TestClient，等价于对该 ASGI 应用发起真实 HTTP 请求。
"""

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
