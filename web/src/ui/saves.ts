/** 存档视图：GET /saves、GET / PUT / DELETE /saves/{slot}。 */

import { api } from '../api/endpoints';
import type { RunSnapshot, SaveDetail } from '../types/api';
import { SNAPSHOT_VERSION } from '../types/api';
import type { Child } from './dom';
import { badge, describeError, el, formatNumber, jsonBlock, mountAsync, parseJson, showToast, table } from './dom';

/** 契约 SaveRequest.example 的快照样例，作为「写入快照」的默认填充值。 */
const TEMPLATE_SNAPSHOT: RunSnapshot = {
  version: 1,
  level_index: 2,
  level_plants: ['sunflower', 'peashooter'],
  time: 132.5,
  sun: 275,
  killed: 18,
  sky_sun_timer: 3.2,
  wave: {
    index: 3,
    early_trigger_at: -1.0,
    lane_cursor: 2,
    pending: [
      { dt: 4.5, type: 'cone' },
      { dt: 4.5, type: 'basic' },
    ],
  },
  card_cooldowns: { sunflower: 0.0, peashooter: 2.3 },
  plants: [
    { type: 'sunflower', col: 0, row: 2, hp: 300, state: {} },
    { type: 'peashooter', col: 1, row: 2, hp: 300, state: {} },
  ],
  zombies: [
    { type: 'basic', row: 2, x: 1500.0, hp: 200, has_hat: false, hat_hp: 0, state: 0, slow_t: 0.0, bite_t: 0.0 },
  ],
  mowers: [{ row: 0, used: false, running: false, x: 520.0 }],
};

export async function mount(container: HTMLElement): Promise<void> {
  await mountAsync(container, async () => {
    const slots = await api.listSaves();

    const detailBox = el('section', { class: 'card' }, [
      el('h3', { class: 'card__title' }, ['快照详情']),
      el('p', { class: 'state state--empty' }, ['点击下方任意槽位的「读取」查看快照']),
    ]);

    const readSlot = async (slot: number): Promise<void> => {
      await mountAsync(detailBox, async () => {
        const detail: SaveDetail = await api.getSaveSlot(slot);
        return el('div', {}, [
          el('h3', { class: 'card__title' }, [`槽位 ${detail.slot} · ${detail.saved_at}`]),
          jsonBlock(detail.snapshot),
        ]);
      });
    };

    const deleteSlot = async (slot: number): Promise<void> => {
      try {
        await api.deleteSaveSlot(slot);
        showToast(`已删除存档：槽位 ${slot}`);
        void mount(container);
      } catch (error) {
        showToast(`删除失败：${describeError(error)}`, 'error');
      }
    };

    const rows: Child[][] = slots.map((slot) => [
      String(slot.slot),
      slot.empty ? badge('空', 'muted') : badge('已有存档', 'ok'),
      slot.level_name ?? '—',
      slot.time === undefined ? '—' : formatNumber(slot.time, 1),
      slot.sun === undefined ? '—' : String(slot.sun),
      slot.killed === undefined ? '—' : String(slot.killed),
      slot.saved_at ?? '—',
      el('div', { class: 'toolbar' }, [
        (() => {
          const button = el('button', { class: 'button', type: 'button' }, ['读取']);
          button.addEventListener('click', () => {
            void readSlot(slot.slot);
          });
          return button;
        })(),
        (() => {
          const button = el('button', { class: 'button button--danger', type: 'button' }, ['删除']);
          button.disabled = Boolean(slot.empty);
          button.addEventListener('click', () => {
            void deleteSlot(slot.slot);
          });
          return button;
        })(),
      ]),
    ]);

    // ---- 写入 / 覆盖（PUT /saves/{slot}）----
    const slotInput = el('input', { id: 'save-slot', class: 'input', type: 'number', step: '1', value: '2' });
    const textarea = el('textarea', { class: 'textarea', id: 'save-json', spellcheck: false, rows: '14' }, [
      JSON.stringify(TEMPLATE_SNAPSHOT, null, 2),
    ]);
    const putError = el('p', { class: 'field__error', role: 'alert' }, []);
    putError.setAttribute('hidden', '');
    const putForm = el('form', { class: 'card' }, [
      el('h3', { class: 'card__title' }, ['PUT /saves/{slot} 写入 / 覆盖快照']),
      el('div', { class: 'field' }, [
        el('label', { class: 'field__label', for: 'save-slot' }, ['槽位 slot（1~3）']),
        slotInput,
      ]),
      el('div', { class: 'field' }, [
        el('label', { class: 'field__label', for: 'save-json' }, ['snapshot JSON']),
        textarea,
        el('span', { class: 'field__hint' }, [`version 必须为 ${SNAPSHOT_VERSION}，否则返回 2003；槽位非 1~3 返回 2002。`]),
      ]),
      putError,
      el('button', { class: 'button button--primary', type: 'submit' }, ['写入快照']),
    ]);
    putForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      putError.setAttribute('hidden', '');
      try {
        const snapshot = parseJson<RunSnapshot>(textarea.value, 'snapshot JSON');
        const saved = await api.upsertSaveSlot(Number(slotInput.value), snapshot);
        showToast(`存档成功：槽位 ${saved.slot}`);
        void mount(container);
      } catch (error) {
        putError.textContent = describeError(error);
        putError.removeAttribute('hidden');
      }
    });

    return el('div', { class: 'view' }, [
      el('h2', { class: 'view__title' }, ['存档']),
      el('p', { class: 'view__hint' }, ['固定 3 个槽位（1~3），空槽位返回 empty: true；读取空槽位返回 2001。']),
      el('section', { class: 'card' }, [
        el('h3', { class: 'card__title' }, ['GET /saves 槽位列表']),
        table(
          ['槽位', '状态', '关卡', '时间(s)', '阳光', '击杀', '保存时间', '操作'],
          rows,
          { caption: 'RUN_SLOT_MIN..RUN_SLOT_MAX 固定 3 个槽位' },
        ),
      ]),
      detailBox,
      putForm,
    ]);
  });
}
