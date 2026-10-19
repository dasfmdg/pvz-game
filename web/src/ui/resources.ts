/** 资源视图：GET /audio、GET /sprites。 */

import { api } from '../api/endpoints';
import { el, mountAsync, statCard, table } from './dom';

export async function mount(container: HTMLElement): Promise<void> {
  await mountAsync(container, async () => {
    const [audio, sprites] = await Promise.all([api.getAudio(), api.getSprites()]);

    const audioStats = el('div', { class: 'grid' }, [
      statCard('BGM 基础增益', `${audio.bgm_volume_db} dB`),
      statCard('SFX 基础增益', `${audio.sfx_volume_db} dB`),
      statCard('音效对象池', String(audio.pool_size)),
      statCard('音效数量', String(audio.sfx.length)),
    ]);

    return el('div', { class: 'view' }, [
      el('h2', { class: 'view__title' }, ['资源']),
      el('p', { class: 'view__hint' }, ['对齐 SoundManager 与 SpriteMeta / SpriteLibrary 的资源清单。']),
      audioStats,
      el('section', { class: 'card' }, [
        el('h3', { class: 'card__title' }, ['GET /audio · 背景音乐']),
        table(['name', 'path'], [[audio.bgm.name, audio.bgm.path]]),
      ]),
      el('section', { class: 'card' }, [
        el('h3', { class: 'card__title' }, ['GET /audio · 音效清单']),
        table(['name', 'path'], audio.sfx.map((track) => [track.name, track.path]), {
          caption: `共 ${audio.sfx.length} 条`,
        }),
      ]),
      el('section', { class: 'card' }, [
        el('h3', { class: 'card__title' }, ['GET /sprites · 精灵表']),
        table(
          ['name', '单帧尺寸', '帧数', '帧时长', '源路径'],
          sprites.sheets.map((sheet) => [
            sheet.name,
            `${sheet.w}×${sheet.h}`,
            String(sheet.frames),
            sheet.d !== undefined ? `统一 d=${sheet.d}` : `逐帧 delays×${sheet.delays?.length ?? 0}`,
            sheet.src,
          ]),
          { caption: `共 ${sprites.sheets.length} 张` },
        ),
      ]),
      el('div', { class: 'grid grid--wide' }, [
        el('section', { class: 'card' }, [
          el('h3', { class: 'card__title' }, ['静态单图']),
          table(['name', 'path'], sprites.static_textures.map((item) => [item.name, item.path])),
        ]),
        el('section', { class: 'card' }, [
          el('h3', { class: 'card__title' }, ['卡片图']),
          table(['name', 'path'], sprites.card_textures.map((item) => [item.name, item.path])),
        ]),
        el('section', { class: 'card' }, [
          el('h3', { class: 'card__title' }, ['卡片切分区域']),
          table(
            ['name', 'x', 'y', 'w', 'h'],
            sprites.card_regions.map((region) => [
              region.name,
              String(region.x),
              String(region.y),
              String(region.w),
              String(region.h),
            ]),
          ),
        ]),
      ]),
    ]);
  });
}
