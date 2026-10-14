"""错误码、业务异常与统一响应/异常处理。

契约来源：openapi.yaml 的 components.schemas.ErrorCode / ErrorResponse /
components.responses.* 。ErrorCode 枚举与 HTTP 状态码的映射如下：

    2001 存档槽位为空        -> 404
    2002 存档槽位非法(非1~3) -> 400
    2003 快照版本不兼容      -> 409
    3001 关卡不存在          -> 404
    3002 关卡未解锁          -> 409
    4001 参数非法            -> 400
    4002 校验失败            -> 400
    4003 图鉴/资源不存在     -> 404
"""

import logging
from enum import IntEnum

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

logger = logging.getLogger("pvz.errors")


class ErrorCode(IntEnum):
    SLOT_EMPTY = 2001
    SLOT_INVALID = 2002
    SNAPSHOT_CONFLICT = 2003
    LEVEL_NOT_FOUND = 3001
    LEVEL_LOCKED = 3002
    INVALID_PARAM = 4001
    VALIDATION_FAILED = 4002
    ZOMBIE_NOT_FOUND = 4003


_HTTP_STATUS = {
    ErrorCode.SLOT_EMPTY: 404,
    ErrorCode.SLOT_INVALID: 400,
    ErrorCode.SNAPSHOT_CONFLICT: 409,
    ErrorCode.LEVEL_NOT_FOUND: 404,
    ErrorCode.LEVEL_LOCKED: 409,
    ErrorCode.INVALID_PARAM: 400,
    ErrorCode.VALIDATION_FAILED: 400,
    ErrorCode.ZOMBIE_NOT_FOUND: 404,
}

_DEFAULT_MSG = {
    ErrorCode.SLOT_EMPTY: "该槽位暂无存档",
    ErrorCode.SLOT_INVALID: "存档槽位非法",
    ErrorCode.SNAPSHOT_CONFLICT: "快照版本不兼容",
    ErrorCode.LEVEL_NOT_FOUND: "关卡不存在",
    ErrorCode.LEVEL_LOCKED: "关卡未解锁",
    ErrorCode.INVALID_PARAM: "参数非法",
    ErrorCode.VALIDATION_FAILED: "校验失败",
    ErrorCode.ZOMBIE_NOT_FOUND: "僵尸类型不存在",
}


class BizError(Exception):
    """业务异常：携带契约错误码；HTTP 状态码由错误码映射得到。"""

    def __init__(self, code: ErrorCode, msg: str | None = None) -> None:
        self.code = ErrorCode(code)
        self.msg = msg or _DEFAULT_MSG[self.code]
        self.http_status = _HTTP_STATUS[self.code]
        super().__init__(self.msg)


def ok(data, msg: str = "ok") -> dict:
    """成功响应体：{code:0, msg, data}。"""
    return {"code": 0, "msg": msg, "data": data}


def error_body(code: ErrorCode, msg: str) -> dict:
    """错误响应体：{code, msg, data:null}（对应 ErrorResponse schema）。"""
    return {"code": int(code), "msg": msg, "data": None}


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(BizError)
    async def _handle_biz_error(request: Request, exc: BizError) -> JSONResponse:
        logger.warning(
            "[业务错误] code=%s path=%s method=%s msg=%s",
            int(exc.code), request.url.path, request.method, exc.msg,
        )
        return JSONResponse(status_code=exc.http_status,
                            content=error_body(exc.code, exc.msg))

    @app.exception_handler(RequestValidationError)
    async def _handle_validation(request: Request, exc: RequestValidationError) -> JSONResponse:
        # 按 openapi.yaml 各接口声明的 400 响应区分错误码：
        # PUT /settings、POST /progress/levels/{index}/clear、PUT /saves/{slot} -> BadRequest(4001)
        # PUT /progress -> ValidationFailed(4002)，其余默认 4002。
        path, method = request.url.path, request.method
        if (path.endswith("/settings") and method == "PUT") \
                or path.endswith("/clear") \
                or (path.startswith("/api/saves/") and method == "PUT"):
            code = ErrorCode.INVALID_PARAM
        else:
            code = ErrorCode.VALIDATION_FAILED
        logger.warning(
            "[校验失败] code=%s path=%s method=%s errors=%s",
            int(code), path, method, exc.errors(),
        )
        return JSONResponse(
            status_code=_HTTP_STATUS[code],
            content=error_body(code, _DEFAULT_MSG[code]),
        )
