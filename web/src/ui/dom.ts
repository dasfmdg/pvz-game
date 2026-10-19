/** 轻量 DOM 构建工具与通用 UI 片段（零依赖，面向可访问性）。 */

import { ApiError } from '../api/client';

export type Attrs = Record<string, string | number | boolean | undefined>;
export type Child = Node | string;

/** 创建元素：attrs 中 true -> 空属性，false/undefined -> 跳过。 */
export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  attrs: Attrs = {},
  children: Child[] = [],
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (value === undefined || value === false) continue;
    node.setAttribute(key, value === true ? '' : String(value));
  }
  node.append(...children);
  return node;
}

/** 数字格式化（保留指定小数位，去尾零由 CSS 的 tabular-nums 保证对齐）。 */
export function formatNumber(value: number, fractionDigits = 0): string {
  return value.toFixed(fractionDigits);
}

/** 状态徽标。 */
export function badge(label: string, kind: 'ok' | 'warn' | 'night' | 'muted' = 'muted'): HTMLElement {
  return el('span', { class: `badge badge--${kind}` }, [label]);
}

/** 键值统计块。 */
export function statCard(label: string, value: string): HTMLElement {
  return el('div', { class: 'stat' }, [
    el('span', { class: 'stat__label' }, [label]),
    el('span', { class: 'stat__value' }, [value]),
  ]);
}

/** 过滤掉条件渲染产生的空值（null / undefined / false），得到干净的子节点数组。 */
export function compact(children: Array<Child | null | undefined | false>): Child[] {
  return children.filter((child): child is Child => Boolean(child));
}

export interface TableOptions {
  caption?: string;
  interactive?: boolean;
}

/** 构建数据表格（表头带 scope="col"，单元格统一包裹 <td>，语义正确且可访问）。 */
export function table(headers: string[], rows: Child[][], options: TableOptions = {}): HTMLElement {
  const head = el('tr', {}, headers.map((text) => el('th', { scope: 'col' }, [text])));
  const body = el(
    'tbody',
    {},
    rows.map((cells) => el('tr', {}, cells.map((cell) => el('td', {}, [cell])))),
  );
  const children = compact([
    options.caption ? el('caption', {}, [options.caption]) : null,
    el('thead', {}, [head]),
    body,
  ]);
  return el('div', { class: 'table-wrap' }, [
    el('table', { class: options.interactive ? 'table table--interactive' : 'table' }, children),
  ]);
}

/** JSON 只读展示块。 */
export function jsonBlock(value: unknown): HTMLElement {
  return el('pre', { class: 'code' }, [JSON.stringify(value, null, 2)]);
}

/** 右上角瞬时提示。 */
export function showToast(message: string, kind: 'ok' | 'error' = 'ok'): void {
  const toast = el('div', { class: `toast toast--${kind}`, role: 'status' }, [message]);
  document.body.append(toast);
  window.setTimeout(() => toast.remove(), 4000);
}

/** 把异常转成可读文案（优先展示契约错误码）。 */
export function describeError(error: unknown): string {
  if (error instanceof ApiError) return `[${error.code}] ${error.message}`;
  if (error instanceof Error) return error.message;
  return String(error);
}

/**
 * 三态异步渲染：加载中 -> 内容 / 空 / 失败（失败提供重试）。
 * load 返回 null 表示「空状态」。
 */
export async function mountAsync(
  container: HTMLElement,
  load: () => Promise<HTMLElement | null>,
): Promise<void> {
  container.replaceChildren(el('div', { class: 'state state--loading', role: 'status' }, ['加载中…']));
  try {
    const content = await load();
    if (content === null) {
      container.replaceChildren(el('div', { class: 'state state--empty' }, ['暂无数据']));
      return;
    }
    container.replaceChildren(content);
  } catch (error) {
    const retry = el('button', { class: 'button button--danger', type: 'button' }, ['重试']);
    retry.addEventListener('click', () => {
      void mountAsync(container, load);
    });
    container.replaceChildren(
      el('div', { class: 'state state--error', role: 'alert' }, [`加载失败：${describeError(error)}`, retry]),
    );
  }
}

/** 解析 JSON 文本框；非法时抛出带中文说明的错误。 */
export function parseJson<T>(raw: string, fieldName: string): T {
  try {
    return JSON.parse(raw) as T;
  } catch {
    throw new Error(`${fieldName} 不是合法 JSON`);
  }
}
