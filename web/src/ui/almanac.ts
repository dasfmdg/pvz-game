/** 图鉴视图：GET /plants、GET /zombies、GET /zombies/{id}。 */

import { api } from '../api/endpoints';
import type { Plant, Zombie } from '../types/api';
import { badge, compact, el, jsonBlock, mountAsync, table } from './dom';

function zombieDetail(zombie: Zombie): HTMLElement {
  const optional: Array<[string, unknown]> = [
    ['hat_hp', zombie.hat_hp],
    ['hat_ratio', zombie.hat_ratio],
    ['hat_removed_speed', zombie.hat_removed_speed],
    ['hat_removed_walk', zombie.hat_removed_walk],
    ['has_flag', zombie.has_flag],
    ['jump', zombie.jump],
    ['rip', zombie.rip],
  ];
  const present = optional.filter(([, value]) => value !== undefined);

  return el('div', {}, compact([
    el('h3', { class: 'card__title' }, [`僵尸 ${zombie.id} · ${zombie.name}`]),
    el('div', { class: 'grid' }, [
      el('p', {}, [`生命 ${zombie.hp} · 速度 ${zombie.speed}`]),
      el('p', {}, [`绘制尺寸 ${zombie.zw} × ${zombie.zh}`]),
      el('p', {}, [`行走动画 ${zombie.walk} · 啃食动画 ${zombie.attack}`]),
    ]),
    present.length > 0
      ? el('div', { class: 'toolbar' }, present.map(([key, value]) => badge(`${key}=${String(value)}`, 'muted')))
      : null,
    el('h4', {}, ['完整配置']),
    jsonBlock(zombie),
  ]));
}

export async function mount(container: HTMLElement): Promise<void> {
  await mountAsync(container, async () => {
    const [plants, zombies] = await Promise.all([api.listPlants(), api.listZombies()]);

    const detailBox = el('section', { class: 'card' }, [
      el('h3', { class: 'card__title' }, ['僵尸详情']),
      el('p', { class: 'state state--empty' }, ['点击下方任意僵尸的「详情」查看完整配置']),
    ]);

    const showDetail = async (id: string): Promise<void> => {
      await mountAsync(detailBox, async () => zombieDetail(await api.getZombie(id)));
    };

    const plantRows = plants.map((plant: Plant) => [
      plant.id,
      plant.name,
      String(plant.cost),
      String(plant.hp),
      String(plant.recharge),
      plant.unlock_level === 0 ? badge('开局即拥有', 'ok') : badge(`第 ${plant.unlock_level} 关`, 'muted'),
    ]);

    const zombieRows = zombies.map((zombie) => {
      const button = el('button', { class: 'button', type: 'button' }, ['详情']);
      button.addEventListener('click', () => {
        void showDetail(zombie.id);
      });
      return [
        zombie.id,
        zombie.name,
        String(zombie.hp),
        String(zombie.speed),
        `${zombie.zw}×${zombie.zh}`,
        zombie.hat_hp === undefined ? '—' : String(zombie.hat_hp),
        button,
      ];
    });

    return el('div', { class: 'view' }, [
      el('h2', { class: 'view__title' }, ['图鉴']),
      el('p', { class: 'view__hint' }, ['植物按 PLANT_ORDER（图鉴展示顺序）输出；僵尸键名与 GameConfig.ZOMBIES 完全一致。']),
      el('section', { class: 'card' }, [
        el('h3', { class: 'card__title' }, ['GET /plants 植物数值']),
        table(['id', '名称', '阳光', '生命', '冷却(s)', '解锁'], plantRows, { caption: `共 ${plants.length} 种` }),
      ]),
      el('section', { class: 'card' }, [
        el('h3', { class: 'card__title' }, ['GET /zombies 僵尸图鉴']),
        table(['id', '名称', '生命', '速度', '尺寸', '顶具生命', '操作'], zombieRows, {
          caption: `共 ${zombies.length} 种`,
        }),
      ]),
      detailBox,
    ]);
  });
}
