/** 应用入口：顶部状态栏 + 视图导航 + 视图容器。 */

import './styles.css';

import { API_BASE } from './api/client';
import { api } from './api/endpoints';
import { describeError, el } from './ui/dom';
import * as almanac from './ui/almanac';
import * as levels from './ui/levels';
import * as overview from './ui/overview';
import * as progress from './ui/progress';
import * as resources from './ui/resources';
import * as saves from './ui/saves';
import * as settings from './ui/settings';

interface ViewDefinition {
  id: string;
  label: string;
  hint: string;
  mount: (container: HTMLElement) => Promise<void>;
}

/** 7 个视图覆盖 18 个 operation（逐条见 README 的需求→证据对照）。 */
const VIEWS: ViewDefinition[] = [
  { id: 'overview', label: '概览', hint: 'getOverview', mount: overview.mount },
  { id: 'settings', label: '设置', hint: 'getSettings / updateSettings', mount: settings.mount },
  { id: 'progress', label: '进度', hint: 'getProgress / updateProgress / clearLevel', mount: progress.mount },
  { id: 'saves', label: '存档', hint: 'listSaves / getSaveSlot / upsertSaveSlot / deleteSaveSlot', mount: saves.mount },
  { id: 'levels', label: '关卡', hint: 'listLevels / getLevel / getLevelPlants', mount: levels.mount },
  { id: 'almanac', label: '图鉴', hint: 'listPlants / listZombies / getZombie', mount: almanac.mount },
  { id: 'resources', label: '资源', hint: 'getAudio / getSprites', mount: resources.mount },
];

function app(): void {
  const root = document.querySelector<HTMLDivElement>('#app');
  if (root === null) throw new Error('页面缺少 #app 挂载点');

  const statusBadge = el('span', { class: 'badge badge--muted' }, ['检测后端连通性…']);
  const header = el('header', { class: 'app__header' }, [
    el('div', {}, [
      el('h1', { class: 'app__title' }, ['pvz-game · 后端接口对接控制台']),
      el('p', { class: 'app__subtitle' }, [`接口基址 ${API_BASE}（统一响应体 { code, msg, data }）`]),
    ]),
    statusBadge,
  ]);

  const viewContainer = el('main', { id: 'view' });
  const buttons = new Map<string, HTMLButtonElement>();

  const nav = el(
    'nav',
    { class: 'nav', 'aria-label': '接口视图' },
    VIEWS.map((view) => {
      const button = el('button', { class: 'nav__button', type: 'button' }, [view.label]);
      button.title = view.hint;
      button.addEventListener('click', () => {
        select(view.id);
      });
      buttons.set(view.id, button);
      return button;
    }),
  );

  const select = (id: string): void => {
    const view = VIEWS.find((candidate) => candidate.id === id);
    if (view === undefined) return;
    for (const [key, button] of buttons) {
      if (key === id) {
        button.setAttribute('aria-current', 'page');
      } else {
        button.removeAttribute('aria-current');
      }
    }
    viewContainer.replaceChildren();
    void view.mount(viewContainer);
  };

  root.replaceChildren(el('div', { class: 'app' }, [header, nav, viewContainer]));

  void (async () => {
    try {
      const data = await api.getOverview();
      statusBadge.className = 'badge badge--ok';
      statusBadge.textContent = `后端已连通 · 已解锁下标 ${data.unlocked_level} / 共 ${data.total_levels} 关`;
    } catch (error) {
      statusBadge.className = 'badge badge--warn';
      statusBadge.textContent = `后端未连通：${describeError(error)}`;
    }
  })();

  select('overview');
}

app();
