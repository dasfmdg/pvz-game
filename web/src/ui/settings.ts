/** 设置视图：GET / PUT /settings（音量 0.0~1.0，越界由后端返回 4001）。 */

import { api } from '../api/endpoints';
import type { Settings } from '../types/api';
import { describeError, el, mountAsync, showToast } from './dom';

function volumeField(id: string, label: string, value: number): { field: HTMLElement; input: HTMLInputElement } {
  const input = el('input', {
    id,
    class: 'input',
    type: 'number',
    step: '0.01',
    value: String(value),
    required: true,
    inputmode: 'decimal',
  });
  const field = el('div', { class: 'field' }, [
    el('label', { class: 'field__label', for: id }, [label]),
    input,
    el('span', { class: 'field__hint', id: `${id}-hint` }, ['取值 0.0~1.0；越界值由后端返回 4001（参数非法）。']),
  ]);
  input.setAttribute('aria-describedby', `${id}-hint`);
  return { field, input };
}

export async function mount(container: HTMLElement): Promise<void> {
  await mountAsync(container, async () => {
    const current = await api.getSettings();

    const bgm = volumeField('bgm_volume', '背景音乐音量 bgm_volume', current.bgm_volume);
    const sfx = volumeField('sfx_volume', '音效音量 sfx_volume', current.sfx_volume);

    const mutedInput = el('input', { id: 'muted', type: 'checkbox', checked: current.muted });
    const mutedRow = el('div', { class: 'checkbox-row' }, [
      mutedInput,
      el('label', { class: 'field__label', for: 'muted' }, ['静音 muted']),
    ]);

    const errorBox = el('p', { class: 'field__error', role: 'alert' }, []);
    errorBox.setAttribute('hidden', '');

    const submit = el('button', { class: 'button button--primary', type: 'submit' }, ['保存设置']);
    const reload = el('button', { class: 'button', type: 'button' }, ['重新读取']);
    reload.addEventListener('click', () => {
      void mount(container);
    });

    const form = el('form', { class: 'card' }, [
      el('h3', { class: 'card__title' }, ['参数']),
      bgm.field,
      sfx.field,
      mutedRow,
      errorBox,
      el('div', { class: 'toolbar' }, [submit, reload]),
    ]);

    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      errorBox.setAttribute('hidden', '');
      const payload: Settings = {
        bgm_volume: Number(bgm.input.value),
        sfx_volume: Number(sfx.input.value),
        muted: mutedInput.checked,
      };
      try {
        const saved = await api.updateSettings(payload);
        bgm.input.value = String(saved.bgm_volume);
        sfx.input.value = String(saved.sfx_volume);
        mutedInput.checked = saved.muted;
        showToast(`设置已保存：BGM ${saved.bgm_volume} / SFX ${saved.sfx_volume}`);
      } catch (error) {
        errorBox.textContent = describeError(error);
        errorBox.removeAttribute('hidden');
      }
    });

    return el('div', { class: 'view' }, [
      el('h2', { class: 'view__title' }, ['设置']),
      el('p', { class: 'view__hint' }, ['GET /settings 读取，PUT /settings 覆盖保存；契约采用严格校验，不做静默裁剪。']),
      form,
    ]);
  });
}
