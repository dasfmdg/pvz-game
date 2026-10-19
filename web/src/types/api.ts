/**
 * 契约类型定义：逐字段对齐 openapi.yaml 的 components.schemas（27 个 schema）。
 *
 * 约定：
 * - 字段名一律保持 snake_case（与后端 / OpenAPI 契约完全一致，不做驼峰转换）；
 * - 统一响应体为 { code, msg, data }，code = 0 表示成功；
 * - 关卡下标 0 基（0~39）；存档槽位 1~3；快照版本恒为 1。
 */

/** components.schemas.ErrorCode：契约定义的 8 个业务错误码。 */
export type ErrorCode = 2001 | 2002 | 2003 | 3001 | 3002 | 4001 | 4002 | 4003;

/** components.schemas.Envelope：统一响应体。 */
export interface Envelope<T> {
  code: number;
  msg: string;
  data: T;
}

/** components.schemas.ErrorResponse：业务错误响应。 */
export interface ErrorResponse {
  code: ErrorCode;
  msg: string;
  data: null;
}

// ---------- 设置 ----------
/** components.schemas.Settings */
export interface Settings {
  bgm_volume: number;
  sfx_volume: number;
  muted: boolean;
}

// ---------- 进度 ----------
/** components.schemas.LevelProgress */
export interface LevelProgress {
  cleared: boolean;
  best_kills: number;
}

/** components.schemas.Progress */
export interface Progress {
  unlocked_level: number;
  /** 键为关卡下标的字符串（仅含有记录的关卡） */
  levels: Record<string, LevelProgress>;
}

// ---------- 关卡 ----------
/** 场景类型（LevelSummary / LevelDetail 的 scene 枚举）。 */
export type SceneType = 'day' | 'night';

/** 僵尸类型 id（Wave.z / LevelDetail.zombies / ZombieSnapshot.type 等处的枚举）。 */
export type ZombieId =
  | 'basic'
  | 'cone'
  | 'bucket'
  | 'football'
  | 'door'
  | 'flag'
  | 'pole'
  | 'newspaper';

/** components.schemas.Wave */
export interface Wave {
  t: number;
  z: ZombieId[];
  huge?: boolean;
}

/** components.schemas.LevelSummary */
export interface LevelSummary {
  id: number;
  name: string;
  difficulty: number;
  start_sun: number;
  scene: SceneType;
  cleared: boolean;
  best_kills: number;
  unlocked: boolean;
}

/** components.schemas.LevelDetail */
export interface LevelDetail {
  id: number;
  name: string;
  difficulty: number;
  start_sun: number;
  scene: SceneType;
  waves: Wave[];
  available_plants: string[];
  seed_slot_limit: number;
  needs_seed_select: boolean;
  zombies: ZombieId[];
}

// ---------- 图鉴 ----------
/** components.schemas.Plant */
export interface Plant {
  id: string;
  name: string;
  cost: number;
  hp: number;
  recharge: number;
  unlock_level: number;
}

/** components.schemas.Zombie */
export interface Zombie {
  id: ZombieId;
  name: string;
  hp: number;
  speed: number;
  zw: number;
  zh: number;
  walk: string;
  attack: string;
  dirty_walk?: string;
  dirty_attack?: string;
  dirt_ratio?: number;
  hat_hp?: number;
  hat_ratio?: number;
  hat_removed_speed?: number;
  hat_removed_walk?: string;
  hat_removed_attack?: string;
  has_flag?: boolean;
  jump?: string;
  after_jump_walk?: string;
  rip?: string;
}

// ---------- 单局快照 ----------
/** components.schemas.PlantSnapshot */
export interface PlantSnapshot {
  type: string;
  col: number;
  row: number;
  hp: number;
  state: Record<string, unknown>;
}

/** components.schemas.ZombieSnapshot */
export interface ZombieSnapshot {
  type: ZombieId;
  row: number;
  x: number;
  hp: number;
  has_hat: boolean;
  hat_hp: number;
  /** 0 = Walk，1 = Eat（Dying / Burnt 等瞬态不入档） */
  state: 0 | 1;
  slow_t: number;
  bite_t: number;
}

/** components.schemas.MowerSnapshot */
export interface MowerSnapshot {
  row: number;
  used: boolean;
  running: boolean;
  x: number;
}

/** components.schemas.PendingSpawn */
export interface PendingSpawn {
  dt: number;
  type: ZombieId;
}

/** components.schemas.WaveSnapshot */
export interface WaveSnapshot {
  index: number;
  early_trigger_at: number;
  lane_cursor: number;
  pending: PendingSpawn[];
}

/** components.schemas.RunSnapshot */
export interface RunSnapshot {
  /** 快照结构版本，当前恒为 1 */
  version: 1;
  level_index: number;
  level_plants: string[];
  time: number;
  sun: number;
  killed: number;
  sky_sun_timer?: number;
  wave: WaveSnapshot;
  card_cooldowns?: Record<string, number>;
  plants: PlantSnapshot[];
  zombies: ZombieSnapshot[];
  mowers: MowerSnapshot[];
}

/** components.schemas.SaveSlot */
export interface SaveSlot {
  slot: number;
  /** 空槽位标记；非空时不返回该字段 */
  empty?: boolean;
  level_index?: number;
  level_name?: string;
  time?: number;
  sun?: number;
  killed?: number;
  saved_at?: string;
}

/** components.schemas.SaveDetail */
export interface SaveDetail {
  slot: number;
  saved_at: string;
  snapshot: RunSnapshot;
}

/** components.schemas.SaveRequest */
export interface SaveRequest {
  snapshot: RunSnapshot;
}

// ---------- 资源 ----------
/** components.schemas.AudioTrack */
export interface AudioTrack {
  name: string;
  path: string;
}

/** components.schemas.AudioInfo */
export interface AudioInfo {
  bgm: AudioTrack;
  sfx: AudioTrack[];
  pool_size: number;
  sfx_volume_db: number;
  bgm_volume_db: number;
}

/** components.schemas.SpriteSheet */
export interface SpriteSheet {
  name: string;
  w: number;
  h: number;
  frames: number;
  /** 统一帧时长（秒）；仅当未单独维护 delays 时存在 */
  d?: number;
  /** 逐帧时长（秒）；仅部分精灵表单独维护 */
  delays?: number[];
  src: string;
}

/** components.schemas.NamedResource */
export interface NamedResource {
  name: string;
  path: string;
}

/** components.schemas.CardRegion */
export interface CardRegion {
  name: string;
  x: number;
  y: number;
  w: number;
  h: number;
}

/** components.schemas.SpritesInfo */
export interface SpritesInfo {
  sheets: SpriteSheet[];
  static_textures: NamedResource[];
  card_textures: NamedResource[];
  card_regions: CardRegion[];
}

// ---------- 概览 ----------
/** components.schemas.Overview */
export interface Overview {
  unlocked_level: number;
  total_levels: number;
  cleared_levels: number;
  total_best_kills: number;
  latest_save: SaveSlot | null;
  settings: Settings | null;
}

// ---------- 组合响应 ----------
/** POST /progress/levels/{index}/clear 的 data */
export interface ClearLevelResult {
  unlocked_level: number;
  level: LevelProgress;
}

/** 错误码 -> 默认中文文案（与 openapi.yaml components.responses 的示例一致）。 */
export const ERROR_CODE_MESSAGES: Record<ErrorCode, string> = {
  2001: '该槽位暂无存档',
  2002: '存档槽位非法',
  2003: '快照版本不兼容',
  3001: '关卡不存在',
  3002: '关卡未解锁',
  4001: '参数非法',
  4002: '校验失败',
  4003: '僵尸类型不存在',
};

/** 关卡下标合法区间（0 基，共 40 关）。 */
export const LEVEL_INDEX_MIN = 0;
export const LEVEL_INDEX_MAX = 39;

/** 存档槽位合法区间。 */
export const RUN_SLOT_MIN = 1;
export const RUN_SLOT_MAX = 3;

/** 快照结构版本（SNAPSHOT_VERSION）。 */
export const SNAPSHOT_VERSION = 1;
