/**
 * 分模块接口调用：与 openapi.yaml 的 18 个 operation 一一对应。
 *
 * 命名对齐契约的 operationId，便于逐条比对（见 README 的「需求 → 证据」对照）。
 */

import type {
  AudioInfo,
  ClearLevelResult,
  LevelDetail,
  LevelSummary,
  Overview,
  Plant,
  Progress,
  RunSnapshot,
  SaveDetail,
  SaveRequest,
  SaveSlot,
  Settings,
  SpritesInfo,
  Zombie,
} from '../types/api';
import { request } from './client';

/** 概览 */
export const getOverview = (): Promise<Overview> => request<Overview>('/overview');

/** 设置 */
export const getSettings = (): Promise<Settings> => request<Settings>('/settings');

export const updateSettings = (settings: Settings): Promise<Settings> =>
  request<Settings>('/settings', { method: 'PUT', json: settings });

/** 进度 */
export const getProgress = (): Promise<Progress> => request<Progress>('/progress');

export const updateProgress = (progress: Progress): Promise<Progress> =>
  request<Progress>('/progress', { method: 'PUT', json: progress });

export const clearLevel = (index: number, kills: number): Promise<ClearLevelResult> =>
  request<ClearLevelResult>(`/progress/levels/${index}/clear`, { method: 'POST', json: { kills } });

/** 存档 */
export const listSaves = (): Promise<SaveSlot[]> => request<SaveSlot[]>('/saves');

export const getSaveSlot = (slot: number): Promise<SaveDetail> => request<SaveDetail>(`/saves/${slot}`);

export const upsertSaveSlot = (slot: number, snapshot: RunSnapshot): Promise<{ slot: number }> =>
  request<{ slot: number }>(`/saves/${slot}`, {
    method: 'PUT',
    json: { snapshot } satisfies SaveRequest,
  });

export const deleteSaveSlot = (slot: number): Promise<null> =>
  request<null>(`/saves/${slot}`, { method: 'DELETE' });

/** 关卡 */
export const listLevels = (): Promise<LevelSummary[]> => request<LevelSummary[]>('/levels');

export const getLevel = (index: number): Promise<LevelDetail> => request<LevelDetail>(`/levels/${index}`);

export const getLevelPlants = (index: number): Promise<string[]> =>
  request<string[]>(`/levels/${index}/plants`);

/** 图鉴 */
export const listPlants = (): Promise<Plant[]> => request<Plant[]>('/plants');

export const listZombies = (): Promise<Zombie[]> => request<Zombie[]>('/zombies');

export const getZombie = (id: string): Promise<Zombie> => request<Zombie>(`/zombies/${id}`);

/** 资源 */
export const getAudio = (): Promise<AudioInfo> => request<AudioInfo>('/audio');

export const getSprites = (): Promise<SpritesInfo> => request<SpritesInfo>('/sprites');

/** 统一导出，便于按模块取用。 */
export const api = {
  getOverview,
  getSettings,
  updateSettings,
  getProgress,
  updateProgress,
  clearLevel,
  listSaves,
  getSaveSlot,
  upsertSaveSlot,
  deleteSaveSlot,
  listLevels,
  getLevel,
  getLevelPlants,
  listPlants,
  listZombies,
  getZombie,
  getAudio,
  getSprites,
} as const;
