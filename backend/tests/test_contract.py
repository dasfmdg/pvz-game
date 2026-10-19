"""契约一致性测试：openapi.yaml ↔ FastAPI 实现零偏差。

覆盖：
- 14 path / 18 operation 全部被实现，且实现中不存在契约外的 /api 路由；
- operationId 集合与契约完全一致且唯一；
- 所有 $ref 可解析；
- 2xx 成功响应均基于 Envelope；
- ErrorCode 枚举与实现一致；
- /saves/{slot} 三个操作声明的槽位错误码完整。
"""

import pathlib

import pytest
import yaml

from app.errors import ErrorCode
from app.main import app

SPEC_PATH = pathlib.Path(__file__).resolve().parents[2] / "openapi.yaml"
SPEC = yaml.safe_load(SPEC_PATH.read_text(encoding="utf-8"))

HTTP_METHODS = {"get", "put", "post", "delete", "patch"}


def _spec_operations():
    operations = {}
    for path, item in SPEC["paths"].items():
        for method, operation in item.items():
            if method in HTTP_METHODS:
                operations[(path, method.upper())] = operation
    return operations


def _impl_operations():
    """从应用自身生成的 OpenAPI 文档读取实现侧接口集合。

    FastAPI 0.143 的 include_router 会产出 _IncludedRouter 包装对象，
    直接遍历 app.routes 拿不到末端路由，故改用 app.openapi() 这一实现侧的权威视图。
    """
    schema = app.openapi()
    operations = {}
    for path, item in schema["paths"].items():
        for method, operation in item.items():
            if method in HTTP_METHODS:
                operations[(path, method.upper())] = operation.get("operationId")
    return operations


def test_spec_shape_matches_documented_contract():
    assert len(SPEC["paths"]) == 14
    assert len(_spec_operations()) == 18
    assert len(SPEC["components"]["schemas"]) == 27


def test_every_spec_operation_is_implemented():
    impl = _impl_operations()
    missing = [
        (path, method)
        for (path, method) in _spec_operations()
        if ("/api" + path, method) not in impl
    ]
    assert missing == []


def test_no_undeclared_api_operations():
    impl = set(_impl_operations())
    declared = {("/api" + path, method) for (path, method) in _spec_operations()}
    assert impl == declared


def test_operation_ids_unique_and_aligned():
    spec_ids = sorted(operation["operationId"] for operation in _spec_operations().values())
    assert len(spec_ids) == len(set(spec_ids))
    impl_ids = sorted(_impl_operations().values())
    assert impl_ids == spec_ids


def test_all_refs_resolve():
    refs = set()

    def collect(node):
        if isinstance(node, dict):
            for key, value in node.items():
                if key == "$ref" and isinstance(value, str):
                    refs.add(value)
                else:
                    collect(value)
        elif isinstance(node, list):
            for item in node:
                collect(item)

    collect(SPEC)

    missing = []
    for ref in refs:
        if not ref.startswith("#/"):
            continue
        cursor = SPEC
        for part in ref[2:].split("/"):
            if not isinstance(cursor, dict) or part not in cursor:
                missing.append(ref)
                break
            cursor = cursor[part]
    assert missing == []


def test_success_responses_are_envelope_based():
    for (path, method), operation in _spec_operations().items():
        for status, response in operation.get("responses", {}).items():
            if not status.startswith("2"):
                continue
            schema = response["content"]["application/json"]["schema"]
            assert schema == {"$ref": "#/components/schemas/Envelope"} or "allOf" in schema, (
                path, method, status,
            )


def test_every_operation_has_summary_and_success_example():
    for (path, method), operation in _spec_operations().items():
        assert operation.get("summary"), (path, method)
        assert operation.get("operationId"), (path, method)
        for status, response in operation["responses"].items():
            if status.startswith("2"):
                assert response["content"]["application/json"].get("example"), (path, method, status)


def test_error_code_enum_matches_implementation():
    spec_codes = set(SPEC["components"]["schemas"]["ErrorCode"]["enum"])
    impl_codes = {int(code) for code in ErrorCode}
    assert spec_codes == impl_codes


def test_save_slot_operations_declare_slot_error_codes():
    slot_item = SPEC["paths"]["/saves/{slot}"]
    for method in ("get", "put", "delete"):
        responses = slot_item[method]["responses"]
        assert "400" in responses, method  # 槽位非 1~3 -> 2002
    assert "404" in slot_item["get"]["responses"]
    assert "404" in slot_item["delete"]["responses"]  # 空槽位 -> 2001


@pytest.mark.parametrize("code", [2002, 2001, 2003, 3001, 3002, 4001, 4002, 4003])
def test_each_error_code_is_reachable_from_some_response(code):
    # 每个契约错误码都至少被一处响应示例引用（保证不存在“定义了却无处发生”的死码）
    blob = yaml.safe_dump(SPEC["components"]["responses"], allow_unicode=True)
    assert f"code: {code}" in blob
