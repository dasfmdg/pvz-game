/** 关卡视图：GET /levels、GET /levels/{index}、GET /levels/{index}/plants。 */

import { api } from '../api/endpoints';
import type { LevelDetail, LevelSummary } from '../types/api';
import { badge, compact, el, mountAsync, statCard, table } from './dom';

function sceneBadge(scene: string): HTMLElement {
  return scene === 'night' ? badge('夜晚', 'night') : badge('白天', 'muted');
}

function renderDetail(detail: LevelDetail, plants: string[]): HTMLElement {
  const waves = el(
    'ul',
    { class: 'waves' },
    detail.waves.map((wave) =>
      el('li', {}, compact([
        el('time', {}, [`+${wave.t.toFixed(1)}s`]),
        el('span', {}, [wave.z.join(' · ')]),
        wave.huge ? badge('大波', 'warn') : null,
      ])),
    ),
  );

  const plantsMatch = plants.join(',') === detail.available_plants.join(',');

  return el('div', {}, [
    el('h3', { class: 'card__title' }, [`关卡 ${detail.id} · ${detail.name}`]),
    el('div', { class: 'grid' }, [
      statCard('难度', String(detail.difficulty)),
      statCard('初始阳光', String(detail.start_sun)),
      statCard('卡片槽上限', String(detail.seed_slot_limit)),
      statCard('需选卡界面', detail.needs_seed_select ? '是（第 7 关起）' : '否'),
    ]),
    el('p', {}, [sceneBadge(detail.scene)]),
    el('h4', {}, [`波次表（${detail.waves.length} 波）`]),
    waves,
    el('h4', {}, [`本关可用植物（${plants.length} 种，GET /levels/{index}/plants）`]),
    el('div', { class: 'grid' }, [
      el('p', {}, [plants.join(' · ') || '—']),
      el('p', { class: 'view__hint' }, [
        `与 GET /levels/{index} 的 available_plants ${plantsMatch ? '一致' : '不一致（契约异常）'}`,
      ]),
    ]),
    el('h4', {}, [`本关僵尸种类（${detail.zombies.length} 种）`]),
    el('div', { class: 'toolbar' }, detail.zombies.map((zombieId) => badge(zombieId, 'muted'))),
  ]);
}

export async function mount(container: HTMLElement): Promise<void> {
  await mountAsync(container, async () => {
    const levels: LevelSummary[] = await api.listLevels();

    const detailBox = el('section', { class: 'card' }, [
      el('h3', { class: 'card__title' }, ['关卡详情']),
      el('p', { class: 'state state--empty' }, ['点击下方任意关卡的「详情」查看波次 / 可用植物 / 僵尸种类']),
    ]);

    const showDetail = async (index: number): Promise<void> => {
      await mountAsync(detailBox, async () => {
        const [detail, plants] = await Promise.all([api.getLevel(index), api.getLevelPlants(index)]);
        return renderDetail(detail, plants);
      });
    };

    const rows = levels.map((level) => {
      const detailButton = el('button', { class: 'button', type: 'button' }, ['详情']);
      detailButton.addEventListener('click', () => {
        void showDetail(level.id);
      });
      return [
        String(level.id),
        level.name,
        String(level.difficulty),
        sceneBadge(level.scene),
        level.cleared ? badge('已通关', 'ok') : badge('未通关', 'muted'),
        String(level.best_kills),
        level.unlocked ? badge('已解锁', 'ok') : badge('未解锁', 'warn'),
        detailButton,
      ];
    });

    return el('div', { class: 'view' }, [
      el('h2', { class: 'view__title' }, ['关卡']),
      el('p', { class: 'view__hint' }, ['下标 0 基，共 40 关（30 主关 + 10 后日谈）；波次由后端下发。']),
      el('section', { class: 'card' }, [
        el('h3', { class: 'card__title' }, ['GET /levels 关卡列表']),
        table(
          ['下标', '名称', '难度', '场景', '状态', '最佳击杀', '解锁', '操作'],
          rows,
          { caption: `共 ${levels.length} 关` },
        ),
      ]),
      detailBox,
    ]);
  });
}
