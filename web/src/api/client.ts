/**
 * 统一请求封装：负责 baseURL 拼接、统一响应体 {code,msg,data} 解包与错误码抛出。
 *
 * 约定（对齐 openapi.yaml）：
 * - 成功：code === 0，返回 data；
 * - 业务失败：HTTP 4xx/5xx 且 code !== 0，抛 ApiError（携带契约错误码）；
 * - 传输失败 / 非法响应体：抛 ApiError，code = NETWORK_ERROR_CODE(-1)。
 */

import type { Envelope, ErrorCode } from '../types/api';
import { ERROR_CODE_MESSAGES } from '../types/api';

/** 后端地址，默认对齐契约 servers[0]（http://localhost:3000/api），可用 VITE_API_BASE 覆盖。 */
export const API_BASE: string =
  (import.meta.env.VITE_API_BASE as string | undefined) ?? 'http://localhost:3000/api';

/** 非契约错误码：传输失败或响应体不符合统一约定。 */
export const NETWORK_ERROR_CODE = -1;

export class ApiError extends Error {
  readonly code: number;
  readonly status: number;

  constructor(code: number, message: string, status: number) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
    this.status = status;
  }

  /** 是否为契约定义的业务错误码。 */
  get isContractError(): boolean {
    return this.code in ERROR_CODE_MESSAGES;
  }
}

export interface RequestOptions {
  method?: 'GET' | 'PUT' | 'POST' | 'DELETE';
  /** 需要序列化为 JSON 请求体的载荷 */
  json?: unknown;
}

export async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = 'GET', json } = options;
  const headers = new Headers({ Accept: 'application/json' });
  const init: RequestInit = { method, headers };
  if (json !== undefined) {
    headers.set('Content-Type', 'application/json');
    init.body = JSON.stringify(json);
  }

  let response: Response;
  try {
    response = await fetch(`${API_BASE}${path}`, init);
  } catch {
    throw new ApiError(
      NETWORK_ERROR_CODE,
      `无法连接后端 ${API_BASE}，请先启动 Mock 后端（uvicorn app.main:app --port 3000）`,
      0,
    );
  }

  let payload: unknown;
  try {
    payload = await response.json();
  } catch {
    throw new ApiError(NETWORK_ERROR_CODE, `响应不是合法 JSON（HTTP ${response.status}）`, response.status);
  }

  if (typeof payload !== 'object' || payload === null || typeof (payload as Envelope<unknown>).code !== 'number') {
    throw new ApiError(NETWORK_ERROR_CODE, '响应体缺少 code 字段，不符合统一响应体约定', response.status);
  }

  const envelope = payload as Envelope<T>;
  if (envelope.code !== 0) {
    const fallback = ERROR_CODE_MESSAGES[envelope.code as ErrorCode] ?? '请求失败';
    throw new ApiError(envelope.code, envelope.msg || fallback, response.status);
  }

  return envelope.data;
}
