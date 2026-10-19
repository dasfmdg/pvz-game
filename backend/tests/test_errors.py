"""单元测试：错误码、业务异常与统一响应体构造。"""

import pytest

from app.errors import (
    _DEFAULT_MSG,
    _HTTP_STATUS,
    BizError,
    ErrorCode,
    error_body,
    ok,
)


def test_error_code_enum_matches_contract():
    # 与 openapi.yaml components.schemas.ErrorCode 的 enum 完全一致
    assert [int(code) for code in ErrorCode] == [2001, 2002, 2003, 3001, 3002, 4001, 4002, 4003]


@pytest.mark.parametrize(
    "code,status",
    [
        (ErrorCode.SLOT_EMPTY, 404),
        (ErrorCode.SLOT_INVALID, 400),
        (ErrorCode.SNAPSHOT_CONFLICT, 409),
        (ErrorCode.LEVEL_NOT_FOUND, 404),
        (ErrorCode.LEVEL_LOCKED, 409),
        (ErrorCode.INVALID_PARAM, 400),
        (ErrorCode.VALIDATION_FAILED, 400),
        (ErrorCode.ZOMBIE_NOT_FOUND, 404),
    ],
)
def test_http_status_mapping(code, status):
    assert _HTTP_STATUS[code] == status


def test_every_code_has_default_message():
    for code in ErrorCode:
        assert _DEFAULT_MSG[code]


def test_biz_error_default_message():
    exc = BizError(ErrorCode.SLOT_INVALID)
    assert exc.msg == "存档槽位非法"
    assert exc.http_status == 400
    assert int(exc.code) == 2002


def test_biz_error_custom_message():
    exc = BizError(ErrorCode.LEVEL_LOCKED, "该关还没解锁")
    assert exc.msg == "该关还没解锁"
    assert exc.http_status == 409


def test_ok_envelope_shape():
    assert ok({"a": 1}) == {"code": 0, "msg": "ok", "data": {"a": 1}}
    assert ok(None, "已删除存档") == {"code": 0, "msg": "已删除存档", "data": None}


def test_error_body_shape():
    body = error_body(ErrorCode.SLOT_EMPTY, "该槽位暂无存档")
    assert body == {"code": 2001, "msg": "该槽位暂无存档", "data": None}
