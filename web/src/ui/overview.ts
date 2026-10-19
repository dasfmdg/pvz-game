/** 概览视图：GET /overview（主菜单聚合数据）。 */

import { api } from '../api/endpoints';
import { el, formatNumber, mountAsync, statCard } from './dom';

export async function mount(container: HTMLElement): Promise<void> {
  await mountAsync(container, async () => {
    const data = await api.getOverview();

    const stats = el('div', { class: 'grid' }, [
      statCard('已解锁到', `第 ${data.unlocked_level + 1} 关（下标 ${data.unlocked_level}）`),
      statCard('关卡总数', String(data.total_levels)),
      statCard('已通关关卡', String(data.cleared_levels)),
      statCard('累计最佳击杀', String(data.total_best_kills)),
    ]);

    const save = data.latest_save;
    const saveCard = el('section', { class: 'card' }, [
      el('h3', { class: 'card__title' }, ['最新存档']),
      save
        ? el('div', {}, [
            el('p', {}, [`槽位 ${save.slot} · ${save.level_name ?? '—'}`]),
            el('p', {}, [
              `时间 ${formatNumber(save.time ?? 0, 1)}s · 阳光 ${save.sun ?? 0} · 击杀 ${save.killed ?? 0}`,
            ]),
            el('p', {}, [`保存于 ${save.saved_at ?? '—'}`]),
          ])
        : el('p', { class: 'state state--empty' }, ['暂无存档（所有槽位为空）']),
    ]);

    const settings = data.settings;
    const settingsCard = el('section', { class: 'card' }, [
      el('h3', { class: 'card__title' }, ['当前设置']),
      settings
        ? el('p', {}, [
            `BGM ${formatNumber(settings.bgm_volume, 2)} · SFX ${formatNumber(settings.sfx_volume, 2)} · ${
              settings.muted ? '已静音' : '未静音'
            }`,
          ])
        : el('p', { class: 'state state--empty' }, ['暂无设置']),
    ]);

    return el('div', { class: 'view' }, [
      el('h2', { class: 'view__title' }, ['概览']),
      el('p', { class: 'view__hint' }, ['GET /overview — 一次返回解锁进度、通关数、累计最佳击杀、最新存档与设置。']),
      stats,
      el('div', { class: 'grid grid--wide' }, [saveCard, settingsCard]),
    ]);
  });
}
