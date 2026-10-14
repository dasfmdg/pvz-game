"""Pydantic v2 模型：字段与 openapi.yaml 的 components.schemas 一一对应。

用途：请求体校验（Settings / Progress / SaveRequest / ClearRequest），
其余模型用于描述响应结构（响应体在 router 中按这些字段显式构造）。
"""

from pydantic import BaseModel, Field, field_validator

ZOMBIE_IDS = {"basic", "cone", "bucket", "football", "door", "flag", "pole", "newspaper"}


# ---------- 统一响应体 ----------
class Envelope(BaseModel):
    code: int = 0
    msg: str = "ok"
    data: object | None = None


# ---------- 设置 ----------
class Settings(BaseModel):
    bgm_volume: float = Field(ge=0.0, le=1.0)
    sfx_volume: float = Field(ge=0.0, le=1.0)
    muted: bool


# ---------- 进度 ----------
class LevelProgress(BaseModel):
    cleared: bool
    best_kills: int = Field(ge=0)


class Progress(BaseModel):
    unlocked_level: int = Field(ge=0, le=39)
    levels: dict[str, LevelProgress]


class ClearRequest(BaseModel):
    kills: int = Field(ge=0)


# ---------- 关卡 ----------
class Wave(BaseModel):
    t: float = Field(ge=0)
    z: list[str] = Field(min_length=1, max_length=20)
    huge: bool | None = None

    @field_validator("z")
    @classmethod
    def _check_zombies(cls, value: list[str]) -> list[str]:
        for zid in value:
            if zid not in ZOMBIE_IDS:
                raise ValueError(f"未知僵尸类型: {zid}")
        return value


class LevelSummary(BaseModel):
    id: int = Field(ge=0, le=39)
    name: str = Field(min_length=1)
    difficulty: int = Field(ge=1, le=10)
    start_sun: int = Field(ge=0)
    scene: str
    cleared: bool
    best_kills: int = Field(ge=0)
    unlocked: bool


class LevelDetail(BaseModel):
    id: int = Field(ge=0, le=39)
    name: str = Field(min_length=1)
    difficulty: int = Field(ge=1, le=10)
    start_sun: int = Field(ge=0)
    scene: str
    waves: list[Wave] = Field(min_length=1, max_length=12)
    available_plants: list[str] = Field(max_length=13)
    seed_slot_limit: int = Field(ge=1, le=10)
    needs_seed_select: bool
    zombies: list[str] = Field(max_length=8)


# ---------- 植物图鉴 ----------
class Plant(BaseModel):
    id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    cost: int = Field(ge=0)
    hp: int = Field(ge=1)
    recharge: float = Field(ge=0)
    unlock_level: int = Field(ge=0, le=39)


# ---------- 僵尸图鉴 ----------
class Zombie(BaseModel):
    id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    hp: int = Field(ge=1)
    speed: float
    zw: float
    zh: float
    walk: str
    attack: str
    dirty_walk: str | None = None
    dirty_attack: str | None = None
    dirt_ratio: float | None = Field(default=None, ge=0, le=1)
    hat_hp: int | None = Field(default=None, ge=0)
    hat_ratio: float | None = None
    hat_removed_speed: float | None = None
    hat_removed_walk: str | None = None
    hat_removed_attack: str | None = None
    has_flag: bool | None = None
    jump: str | None = None
    after_jump_walk: str | None = None
    rip: str | None = None


# ---------- 单局快照 ----------
class PlantSnapshot(BaseModel):
    type: str
    col: int = Field(ge=0, le=8)
    row: int = Field(ge=0, le=4)
    hp: int = Field(ge=0)
    state: dict = Field(default_factory=dict)


class ZombieSnapshot(BaseModel):
    type: str
    row: int = Field(ge=0, le=4)
    x: float
    hp: int = Field(ge=0)
    has_hat: bool
    hat_hp: int = Field(ge=0)
    state: int = Field(ge=0, le=1)
    slow_t: float = Field(ge=0)
    bite_t: float = Field(ge=0)


class MowerSnapshot(BaseModel):
    row: int = Field(ge=0, le=4)
    used: bool
    running: bool
    x: float


class PendingSpawn(BaseModel):
    dt: float
    type: str

    @field_validator("type")
    @classmethod
    def _check_type(cls, value: str) -> str:
        if value not in ZOMBIE_IDS:
            raise ValueError(f"未知僵尸类型: {value}")
        return value


class WaveSnapshot(BaseModel):
    index: int = Field(ge=0)
    early_trigger_at: float
    lane_cursor: int = Field(ge=0, le=4)
    pending: list[PendingSpawn] = Field(max_length=20)


class RunSnapshot(BaseModel):
    version: int
    level_index: int = Field(ge=0, le=39)
    level_plants: list[str] = Field(max_length=10)
    time: float = Field(ge=0)
    sun: int = Field(ge=0)
    killed: int = Field(ge=0)
    sky_sun_timer: float | None = Field(default=None, ge=0)
    wave: WaveSnapshot
    card_cooldowns: dict[str, float] | None = None
    plants: list[PlantSnapshot] = Field(default_factory=list, max_length=45)
    zombies: list[ZombieSnapshot] = Field(default_factory=list, max_length=200)
    mowers: list[MowerSnapshot] = Field(default_factory=list, max_length=5)


class SaveSlot(BaseModel):
    slot: int = Field(ge=1, le=3)
    empty: bool | None = None
    level_index: int | None = Field(default=None, ge=0, le=39)
    level_name: str | None = None
    time: float | None = Field(default=None, ge=0)
    sun: int | None = Field(default=None, ge=0)
    killed: int | None = Field(default=None, ge=0)
    saved_at: str | None = None


class SaveDetail(BaseModel):
    slot: int = Field(ge=1, le=3)
    saved_at: str
    snapshot: RunSnapshot


class SaveRequest(BaseModel):
    snapshot: RunSnapshot


# ---------- 概览 ----------
class Overview(BaseModel):
    unlocked_level: int = Field(ge=0, le=39)
    total_levels: int = Field(ge=1)
    cleared_levels: int = Field(ge=0)
    total_best_kills: int = Field(ge=0)
    latest_save: SaveSlot | None = None
    settings: Settings | None = None


# ---------- 音频资源 ----------
class AudioTrack(BaseModel):
    name: str = Field(min_length=1)
    path: str


class AudioInfo(BaseModel):
    bgm: AudioTrack
    sfx: list[AudioTrack] = Field(max_length=10)
    pool_size: int = Field(ge=1)
    sfx_volume_db: float
    bgm_volume_db: float


# ---------- 精灵资源 ----------
class SpriteSheet(BaseModel):
    name: str = Field(min_length=1)
    w: int = Field(ge=1)
    h: int = Field(ge=1)
    frames: int = Field(ge=1)
    d: float | None = Field(default=None, ge=0)
    delays: list[float] | None = None
    src: str


class NamedResource(BaseModel):
    name: str = Field(min_length=1)
    path: str


class CardRegion(BaseModel):
    name: str = Field(min_length=1)
    x: float
    y: float
    w: float
    h: float


class SpritesInfo(BaseModel):
    sheets: list[SpriteSheet] = Field(max_length=60)
    static_textures: list[NamedResource] = Field(max_length=20)
    card_textures: list[NamedResource] = Field(max_length=20)
    card_regions: list[CardRegion] = Field(max_length=20)
