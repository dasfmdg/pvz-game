/** 进度视图：GET / PUT /progress 与 POST /progress/levels/{index}/clear。 */

import { api } from '../api/endpoints';
import type { Progress } from '../types/api';
import { describeError, el, mountAsync, parseJson, showToast, table } from './dom';

function progressTable(progress: Progress): HTMLElement {
  const keys = Object.keys(progress.levels).sort((a, b) => Number(a) - Number(b));
  if (keys.length === 0) {
    return el('p', { class: 'state state--empty' }, ['还没有任何关卡记录（levels 为空）']);
  }
  return table(
    ['关卡下标', '关卡', '已通关', '最佳击杀'],
    keys.map((key) => {
      const entry = progress.levels[key];
      return [
        key,
        `第 ${Number(key) + 1} 关`,
        entry.cleared ? '是' : '否',
        String(entry.best_kills),
      ];
    }),
    { caption: `已解锁到下标 ${progress.unlocked_level}`, interactive: false },
  );
}

export async function mount(container: HTMLElement): Promise<void> {
  await mountAsync(container, async () => {
    const progress = await api.getProgress();

    // ---- 覆盖保存（PUT /progress）----
    const textarea = el('textarea', {
      class: 'textarea',
      id: 'progress-json',
      spellcheck: false,
      rows: '10',
    }, [JSON.stringify(progress, null, 2)]);
    const putError = el('p', { class: 'field__error', role: 'alert' }, []);
    putError.setAttribute('hidden', '');
    const putButton = el('button', { class: 'button button--primary', type: 'submit' }, ['覆盖保存进度']);
    const putForm = el('form', { class: 'card' }, [
      el('h3', { class: 'card__title' }, ['PUT /progress 覆盖保存']),
      el('div', { class: 'field' }, [
        el('label', { class: 'field__label', for: 'progress-json' }, ['progress JSON']),
        textarea,
        el('span', { class: 'field__hint' }, ['结构对应 SaveManager 的 progress 分区；unlocked_level 越界由后端返回 4002。']),
      ]),
      putError,
      putButton,
    ]);
    putForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      putError.setAttribute('hidden', '');
      try {
        const payload = parseJson<Progress>(textarea.value, 'progress JSON');
        const saved = await api.updateProgress(payload);
        showToast(`进度已保存：unlocked_level = ${saved.unlocked_level}`);
        void mount(container);
      } catch (error) {
        putError.textContent = describeError(error);
        putError.removeAttribute('hidden');
      }
    });

    // ---- 通关上报（POST /progress/levels/{index}/clear）----
    const indexInput = el('input', { id: 'clear-index', class: 'input', type: 'number', step: '1', value: String(progress.unlocked_level) });
    const killsInput = el('input', { id: 'clear-kills', class: 'input', type: 'number', step: '1', value: '18' });
    const clearError = el('p', { class: 'field__error', role: 'alert' }, []);
    clearError.setAttribute('hidden', '');
    const clearResult = el('p', {}, []);
    const clearButton = el('button', { class: 'button button--primary', type: 'submit' }, ['上报通关']);
    const clearForm = el('form', { class: 'card' }, [
      el('h3', { class: 'card__title' }, ['POST /progress/levels/{index}/clear 通关上报']),
      el('div', { class: 'toolbar' }, [
        el('div', { class: 'field' }, [
          el('label', { class: 'field__label', for: 'clear-index' }, ['关卡下标 index（0~39）']),
          indexInput,
        ]),
        el('div', { class: 'field' }, [
          el('label', { class: 'field__label', for: 'clear-kills' }, ['本局击杀 kills']),
          killsInput,
        ]),
        clearButton,
      ]),
      el('span', { class: 'field__hint' }, ['下标越界返回 3001，尚未解锁返回 3002。']),
      clearError,
      clearResult,
    ]);
    clearForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      clearError.setAttribute('hidden', '');
      clearResult.textContent = '';
      try {
        const result = await api.clearLevel(Number(indexInput.value), Number(killsInput.value));
        showToast(`通关已记录：unlocked_level = ${result.unlocked_level}`);
        clearResult.textContent = `上报成功：已解锁下标 ${result.unlocked_level}，本关 best_kills = ${result.level.best_kills}`;
        void mount(container);
      } catch (error) {
        clearError.textContent = describeError(error);
        clearError.removeAttribute('hidden');
      }
    });

    return el('div', { class: 'view' }, [
      el('h2', { class: 'view__title' }, ['进度']),
      el('p', { class: 'view__hint' }, ['对应 SaveManager 的 progress 分区；levels 的键为关卡下标字符串。']),
      el('section', { class: 'card' }, [
        el('h3', { class: 'card__title' }, ['GET /progress']),
        progressTable(progress),
      ]),
      putForm,
      clearForm,
    ]);
  });
}
