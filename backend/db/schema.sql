-- ============================================================================
-- pvz-game 物理库结构 · MySQL 8.0 建表 DDL
--
-- 本文件由 backend/db/generate_schema.py 从 pvz_game.dbml 生成，请勿手工编辑。
-- 事实来源：pvz_game.dbml（DBML）→ 本文件（DDL）→ 实际数据库 → SQLAlchemy 反射。
-- 重新生成：python backend/db/generate_schema.py
-- ============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- --------------------------- 枚举（以 MySQL ENUM 落地） ---------------------------
--   audio_kind: bgm / sfx
--   scene_type: day / night

-- --------------------------- 建表 ---------------------------
-- 共 28 表 / 29 外键（外键内联，按依赖顺序排列，整份 DDL 幂等）

CREATE TABLE IF NOT EXISTS `players` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `player_uid` VARCHAR(64) NOT NULL COMMENT '单机玩家标识（工程无登录鉴权，按设备/玩家维度）',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间（更新时自动刷新）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_players_player_uid` (`player_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='单机玩家维度。工程内无账号 / 鉴权（契约明确「按单机玩家维度处理」），本表为进度、存档、事件提供归属主体。';

CREATE TABLE IF NOT EXISTS `levels` (
  `id` INT NOT NULL COMMENT '关卡下标（0 基，0~39，与 GameConfig.LEVELS[i].id 对齐）',
  `name` VARCHAR(64) NOT NULL COMMENT '关卡显示名（如「第1关 · 初次防守」）',
  `difficulty` TINYINT NOT NULL COMMENT '难度（1~10）',
  `start_sun` INT NOT NULL DEFAULT 0 COMMENT '初始阳光',
  `scene` ENUM('day', 'night') NOT NULL DEFAULT 'day' COMMENT '场景：day / night（缺省 day）',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 GameConfig.LEVELS（共 40 关）。可用植物 / 卡槽上限 / 是否需选卡为派生值（见 game_rules），不冗余落库。';

CREATE TABLE IF NOT EXISTS `plants` (
  `id` VARCHAR(32) NOT NULL COMMENT '植物 id（PLANT_ORDER 顺序，如 sunflower）',
  `name` VARCHAR(64) NOT NULL COMMENT '显示名（工程内为英文名，如 Sunflower）',
  `cost` INT NOT NULL DEFAULT 0 COMMENT '阳光价格',
  `hp` INT NOT NULL DEFAULT 300 COMMENT '生命',
  `recharge` DECIMAL(8,3) NOT NULL DEFAULT 0.000 COMMENT '卡片冷却（秒）',
  `unlock_level` INT NOT NULL DEFAULT 0 COMMENT '0=开局即拥有；否则为对应关序号（1 基）通关后解锁',
  `card_order` INT NOT NULL COMMENT '卡槽展示顺序（PLANT_ORDER 下标）',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 GameConfig.PLANTS + PLANT_UNLOCK + PLANT_ORDER（共 13 种）。';

CREATE TABLE IF NOT EXISTS `audio_tracks` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `name` VARCHAR(64) NOT NULL COMMENT '音效名 / BGM 名（SOUNDS 的键；BGM 名为 background）',
  `kind` ENUM('bgm', 'sfx') NOT NULL COMMENT '类别：bgm / sfx',
  `path` VARCHAR(255) NOT NULL COMMENT 'res:// 资源路径',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_audio_tracks_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 SoundManager.SOUNDS（10 条 sfx）+ BGM_PATH（1 条 bgm），共 11 行。';

CREATE TABLE IF NOT EXISTS `audio_config` (
  `id` TINYINT NOT NULL COMMENT '固定为 1（单例约束）',
  `pool_size` INT NOT NULL DEFAULT 8 COMMENT '音效播放器对象池大小（POOL_SIZE）',
  `sfx_volume_db` DECIMAL(6,2) NOT NULL DEFAULT -6.00 COMMENT '音效基础增益（分贝，SFX_VOLUME_DB）',
  `bgm_volume_db` DECIMAL(6,2) NOT NULL DEFAULT -16.00 COMMENT 'BGM 基础增益（分贝，BGM_VOLUME_DB）',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 SoundManager 的播放器常量，单行配置。';

CREATE TABLE IF NOT EXISTS `sprite_sheets` (
  `name` VARCHAR(64) NOT NULL COMMENT '精灵表名（SHEETS 的键）',
  `w` INT NOT NULL COMMENT '单帧宽（像素）',
  `h` INT NOT NULL COMMENT '单帧高（像素）',
  `frames` INT NOT NULL COMMENT '帧数',
  `d` DECIMAL(6,4) COMMENT '统一帧时长（秒）；仅当未单独维护 delays 时存在',
  `src` VARCHAR(255) NOT NULL COMMENT 'res:// 资源路径',
  `sort_order` INT NOT NULL COMMENT '清单展示顺序（SHEETS 声明顺序下标，0 基；对应 GET /sprites 的 sheets 顺序）',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 SpriteMeta.SHEETS（横向精灵表，共 46 张）。d 与 delays 二选一。';

CREATE TABLE IF NOT EXISTS `static_textures` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `name` VARCHAR(64) NOT NULL COMMENT '素材名（STATIC_TEXTURES 的键）',
  `path` VARCHAR(255) NOT NULL COMMENT 'res:// 资源路径',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_static_textures_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 SpriteLibrary.STATIC_TEXTURES。';

CREATE TABLE IF NOT EXISTS `game_rules` (
  `id` TINYINT NOT NULL COMMENT '固定为 1（单例约束）',
  `total_levels` INT NOT NULL DEFAULT 40 COMMENT '关卡总数（30 主关 + 10 后日谈）',
  `run_slot_min` TINYINT NOT NULL DEFAULT 1 COMMENT '存档槽位下限（RUN_SLOT_MIN）',
  `run_slot_max` TINYINT NOT NULL DEFAULT 3 COMMENT '存档槽位上限（RUN_SLOT_MAX）',
  `snapshot_version` INT NOT NULL DEFAULT 1 COMMENT '当前快照结构版本（SNAPSHOT_VERSION）',
  `grid_cols` TINYINT NOT NULL DEFAULT 9 COMMENT '网格列数（COLS）',
  `grid_rows` TINYINT NOT NULL DEFAULT 5 COMMENT '网格行数（ROWS）',
  `wave_unit_gap` DECIMAL(6,3) NOT NULL DEFAULT 0.900 COMMENT '同波内单僵尸间隔（秒，WAVE_UNIT_GAP）',
  `zombie_bite_interval` DECIMAL(6,3) NOT NULL DEFAULT 0.500 COMMENT '啃食间隔（秒，ZOMBIE_BITE_INTERVAL）',
  `zombie_bite_damage` INT NOT NULL DEFAULT 34 COMMENT '每口啃食伤害（ZOMBIE_BITE_DAMAGE）',
  `slow_factor` DECIMAL(6,4) NOT NULL DEFAULT 0.5000 COMMENT '寒冰减速倍率（SLOW_FACTOR）',
  `slow_duration` DECIMAL(6,3) NOT NULL DEFAULT 5.000 COMMENT '减速持续时长（秒，SLOW_DURATION）',
  `seed_slot_base` TINYINT NOT NULL DEFAULT 5 COMMENT '卡槽基础数（SEED_SLOT_BASE）',
  `seed_slot_step` TINYINT NOT NULL DEFAULT 4 COMMENT '卡槽每增长步长（SEED_SLOT_STEP）',
  `seed_slot_max` TINYINT NOT NULL DEFAULT 10 COMMENT '卡槽上限（SEED_SLOT_MAX）',
  `seed_select_from_level` INT NOT NULL DEFAULT 7 COMMENT '从此关序号（1 基）起需先选卡（SEED_SELECT_FROM_LEVEL）',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='承载配置常量，供 seed_slot_limit / available_plants 等派生计算（单行）。';

CREATE TABLE IF NOT EXISTS `error_codes` (
  `code` INT NOT NULL COMMENT '业务错误码（契约 ErrorCode 取值）',
  `http_status` INT NOT NULL COMMENT '对应 HTTP 状态码',
  `default_msg` VARCHAR(128) NOT NULL COMMENT '默认提示信息',
  `description` VARCHAR(255) COMMENT '错误说明',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='契约层面定义的错误码（工程源码仅 push_warning，无错误码体系）。取值：2001 / 2002 / 2003 / 3001 / 3002 / 4001 / 4002 / 4003。';

CREATE TABLE IF NOT EXISTS `player_settings` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `player_id` BIGINT NOT NULL COMMENT '所属玩家（1:1）',
  `bgm_volume` DECIMAL(4,3) NOT NULL DEFAULT 0.800 COMMENT '背景音乐音量，0.000~1.000（默认 DEFAULT_BGM_VOLUME=0.8）',
  `sfx_volume` DECIMAL(4,3) NOT NULL DEFAULT 1.000 COMMENT '音效音量，0.000~1.000（默认 DEFAULT_SFX_VOLUME=1.0）',
  `muted` TINYINT NOT NULL DEFAULT FALSE COMMENT '是否静音（默认 DEFAULT_MUTED=false）',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_player_settings_player_id` (`player_id`),
  CONSTRAINT `fk_player_settings_player_id` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 save_manager.gd 的 settings 分区（GET / PUT /settings）。';

CREATE TABLE IF NOT EXISTS `player_progress` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `player_id` BIGINT NOT NULL COMMENT '所属玩家（1:1）',
  `unlocked_level` INT NOT NULL DEFAULT 0 COMMENT '已解锁到的最大关卡下标（0 基，0~39）',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_player_progress_player_id` (`player_id`),
  CONSTRAINT `fk_player_progress_player_id` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 save_manager.gd 的 progress.unlocked_level；is_unlocked(i) == i <= unlocked_level。';

CREATE TABLE IF NOT EXISTS `player_level_progress` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `player_id` BIGINT NOT NULL COMMENT '所属玩家',
  `level_index` INT NOT NULL COMMENT '关卡下标（0 基，外键 → levels.id）',
  `cleared` TINYINT NOT NULL DEFAULT FALSE COMMENT '是否已通关',
  `best_kills` INT NOT NULL DEFAULT 0 COMMENT '该关历史最佳击杀数',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_player_level` (`player_id`, `level_index`),
  CONSTRAINT `fk_player_level_progress_player_id` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_player_level_progress_level_index` FOREIGN KEY (`level_index`) REFERENCES `levels` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 progress.levels（{"<关卡号>": {cleared, best_kills}}）；仅落有记录的关卡（已通关或 best_kills>0）。';

CREATE TABLE IF NOT EXISTS `run_saves` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `player_id` BIGINT NOT NULL COMMENT '所属玩家',
  `slot` TINYINT NOT NULL COMMENT '存档槽位，1~3（RUN_SLOT_MIN~RUN_SLOT_MAX）',
  `snapshot_version` INT NOT NULL DEFAULT 1 COMMENT '快照结构版本，恒为 1（SNAPSHOT_VERSION），否则拒绝保存',
  `level_index` INT NOT NULL COMMENT '所在关卡下标（0 基，外键 → levels.id）',
  `level_name` VARCHAR(64) NOT NULL COMMENT '关卡显示名（冗余，供存档列表直接展示）',
  `time` DECIMAL(8,3) NOT NULL DEFAULT 0.000 COMMENT '对局已进行时间（秒）',
  `sun` INT NOT NULL DEFAULT 0 COMMENT '当前阳光',
  `killed` INT NOT NULL DEFAULT 0 COMMENT '当前击杀数',
  `sky_sun_timer` DECIMAL(8,3) NOT NULL DEFAULT 0.000 COMMENT '天降阳光计时器剩余（秒）',
  `saved_at` DATETIME NOT NULL COMMENT '保存时间（契约的 ISO 8601 → datetime）',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_player_slot` (`player_id`, `slot`),
  CONSTRAINT `fk_run_saves_player_id` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_run_saves_level_index` FOREIGN KEY (`level_index`) REFERENCES `levels` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 SaveSlot / SaveDetail 摘要 + RunSnapshot 顶层标量。一槽一档，PUT 为覆盖写。';

CREATE TABLE IF NOT EXISTS `level_waves` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `level_id` INT NOT NULL COMMENT '关卡（外键 → levels.id）',
  `wave_index` INT NOT NULL COMMENT '波次序号（0 基）',
  `t` DECIMAL(8,3) NOT NULL COMMENT '波次开始时间（秒）',
  `huge` TINYINT NOT NULL DEFAULT FALSE COMMENT '是否大波（自动追加旗帜僵尸与横幅）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_level_wave` (`level_id`, `wave_index`),
  CONSTRAINT `fk_level_waves_level_id` FOREIGN KEY (`level_id`) REFERENCES `levels` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 LEVELS[i].waves[]（每关 1~12 波）。波内单僵尸间隔取 game_rules.wave_unit_gap。';

CREATE TABLE IF NOT EXISTS `plant_behaviors` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `plant_id` VARCHAR(32) NOT NULL COMMENT '植物 id（1:1，外键 → plants.id）',
  `params` JSON NOT NULL COMMENT '行为参数（键随植物而异：fire_interval / damage / fuse / arm_time / splash_damage 等）',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_plant_behaviors_plant_id` (`plant_id`),
  CONSTRAINT `fk_plant_behaviors_plant_id` FOREIGN KEY (`plant_id`) REFERENCES `plants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 GameConfig.PLANT_BEHAVIOR（各植物参数异构，故以 JSON 落库）。';

CREATE TABLE IF NOT EXISTS `zombies` (
  `id` VARCHAR(32) NOT NULL COMMENT '僵尸类型 id（ZOMBIES 的键，如 basic）',
  `name` VARCHAR(64) NOT NULL COMMENT '显示名（工程内为英文名）',
  `hp` INT NOT NULL COMMENT '总生命',
  `speed` DECIMAL(8,3) NOT NULL COMMENT '移动速度（像素/秒）',
  `zw` DECIMAL(8,3) NOT NULL COMMENT '绘制宽度',
  `zh` DECIMAL(8,3) NOT NULL COMMENT '绘制高度',
  `walk` VARCHAR(64) NOT NULL COMMENT '行走动画精灵表名（外键 → sprite_sheets.name）',
  `attack` VARCHAR(64) NOT NULL COMMENT '啃食动画精灵表名（外键 → sprite_sheets.name）',
  `dirty_walk` VARCHAR(64) COMMENT '损毁态行走精灵表名（逻辑引用 sprite_sheets.name）',
  `dirty_attack` VARCHAR(64) COMMENT '损毁态啃食精灵表名（逻辑引用 sprite_sheets.name）',
  `dirt_ratio` DECIMAL(6,4) COMMENT '切换损毁外观的生命比例阈值（0~1）',
  `hat_hp` INT COMMENT '顶具（护甲段）独立生命，仅带顶具僵尸存在',
  `hat_ratio` DECIMAL(6,4) COMMENT '顶具外观切换比例，仅带顶具僵尸存在',
  `hat_removed_speed` DECIMAL(8,3) COMMENT '顶具被打掉后的速度，仅部分僵尸存在',
  `hat_removed_walk` VARCHAR(64) COMMENT '顶具被打掉后的行走精灵表名',
  `hat_removed_attack` VARCHAR(64) COMMENT '顶具被打掉后的啃食精灵表名',
  `has_flag` TINYINT COMMENT '是否持旗（仅 flag 僵尸）',
  `jump` VARCHAR(64) COMMENT '翻越动画精灵表名（仅 pole 僵尸）',
  `after_jump_walk` VARCHAR(64) COMMENT '翻越落地后行走精灵表名（仅 pole 僵尸）',
  `rip` VARCHAR(64) COMMENT '报纸撕碎动画精灵表名（仅 newspaper 僵尸）',
  `sort_order` INT NOT NULL COMMENT '图鉴展示顺序（ZOMBIES 声明顺序下标，0 基；对应 GET /zombies 的返回顺序）',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_zombies_walk` FOREIGN KEY (`walk`) REFERENCES `sprite_sheets` (`name`),
  CONSTRAINT `fk_zombies_attack` FOREIGN KEY (`attack`) REFERENCES `sprite_sheets` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 GameConfig.ZOMBIES（8 类：basic / cone / bucket / football / door / flag / pole / newspaper）。源码无 damage / has_hat 字段（啃食伤害为全局常量 zombie_bite_damage）。';

CREATE TABLE IF NOT EXISTS `sprite_frame_delays` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `sheet_name` VARCHAR(64) NOT NULL COMMENT '精灵表名（外键 → sprite_sheets.name）',
  `frame_index` INT NOT NULL COMMENT '帧下标（0 基）',
  `delay_seconds` DECIMAL(6,4) NOT NULL COMMENT '该帧时长（秒）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sheet_frame` (`sheet_name`, `frame_index`),
  CONSTRAINT `fk_sprite_frame_delays_sheet_name` FOREIGN KEY (`sheet_name`) REFERENCES `sprite_sheets` (`name`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 SHEETS[*].delays；无 delays 的精灵表按 d 推导，不落本表。';

CREATE TABLE IF NOT EXISTS `card_textures` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `plant_id` VARCHAR(32) NOT NULL COMMENT '植物 id（1:1，外键 → plants.id）',
  `path` VARCHAR(255) NOT NULL COMMENT 'res:// 资源路径',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_card_textures_plant_id` (`plant_id`),
  CONSTRAINT `fk_card_textures_plant_id` FOREIGN KEY (`plant_id`) REFERENCES `plants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 SpriteLibrary.CARD_TEXTURES（键为植物 id）。';

CREATE TABLE IF NOT EXISTS `card_regions` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `plant_id` VARCHAR(32) NOT NULL COMMENT '植物 id（1:1，外键 → plants.id）',
  `x` DECIMAL(8,2) NOT NULL DEFAULT 0.00 COMMENT '切图起点 x',
  `y` DECIMAL(8,2) NOT NULL DEFAULT 0.00 COMMENT '切图起点 y',
  `w` DECIMAL(8,2) NOT NULL COMMENT '切图宽',
  `h` DECIMAL(8,2) NOT NULL COMMENT '切图高',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_card_regions_plant_id` (`plant_id`),
  CONSTRAINT `fk_card_regions_plant_id` FOREIGN KEY (`plant_id`) REFERENCES `plants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 SpriteLibrary.CARD_REGIONS（Rect2(x, y, w, h)，键为植物 id）。';

CREATE TABLE IF NOT EXISTS `level_clear_events` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `player_id` BIGINT NOT NULL COMMENT '所属玩家',
  `level_index` INT NOT NULL COMMENT '关卡下标（0 基，外键 → levels.id）',
  `kills` INT NOT NULL DEFAULT 0 COMMENT '本局击杀数（clearLevel 上报值）',
  `reported_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '上报时间',
  PRIMARY KEY (`id`),
  KEY `idx_player_time` (`player_id`, `reported_at`),
  KEY `idx_level_time` (`level_index`, `reported_at`),
  CONSTRAINT `fk_level_clear_events_player_id` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_level_clear_events_level_index` FOREIGN KEY (`level_index`) REFERENCES `levels` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='由 POST /progress/levels/{index}/clear 事件落地（追加写，只增不改）。为留存 / 转化 / 击杀分布等运营指标的唯一真实数据源。本工单未含推导视图。';

CREATE TABLE IF NOT EXISTS `run_save_cards` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `save_id` BIGINT NOT NULL COMMENT '所属存档',
  `seq` INT NOT NULL COMMENT '卡槽顺序（0 基）',
  `plant_id` VARCHAR(32) NOT NULL COMMENT '植物 id（外键 → plants.id）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_save_card_seq` (`save_id`, `seq`),
  CONSTRAINT `fk_run_save_cards_save_id` FOREIGN KEY (`save_id`) REFERENCES `run_saves` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_run_save_cards_plant_id` FOREIGN KEY (`plant_id`) REFERENCES `plants` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 RunSnapshot.level_plants（本关携带的卡片植物，最多 10 个）。';

CREATE TABLE IF NOT EXISTS `run_save_card_cooldowns` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `save_id` BIGINT NOT NULL COMMENT '所属存档',
  `plant_id` VARCHAR(32) NOT NULL COMMENT '植物 id（外键 → plants.id）',
  `cooldown_seconds` DECIMAL(8,3) NOT NULL DEFAULT 0.000 COMMENT '该卡剩余冷却（秒）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_save_cd_plant` (`save_id`, `plant_id`),
  CONSTRAINT `fk_run_save_card_cooldowns_save_id` FOREIGN KEY (`save_id`) REFERENCES `run_saves` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_run_save_card_cooldowns_plant_id` FOREIGN KEY (`plant_id`) REFERENCES `plants` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 RunSnapshot.card_cooldowns（键为植物 id）。';

CREATE TABLE IF NOT EXISTS `run_save_wave_states` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `save_id` BIGINT NOT NULL COMMENT '所属存档（1:1）',
  `wave_index` INT NOT NULL DEFAULT 0 COMMENT '当前波次下标',
  `early_trigger_at` DECIMAL(8,3) NOT NULL DEFAULT -1.000 COMMENT '提前触发时刻；-1 表示未触发提前等待',
  `lane_cursor` INT NOT NULL DEFAULT 0 COMMENT '上一只僵尸落位行（0~4）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_run_save_wave_states_save_id` (`save_id`),
  CONSTRAINT `fk_run_save_wave_states_save_id` FOREIGN KEY (`save_id`) REFERENCES `run_saves` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 WaveManager.to_snapshot() 的标量部分。';

CREATE TABLE IF NOT EXISTS `run_save_plants` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `save_id` BIGINT NOT NULL COMMENT '所属存档',
  `seq` INT NOT NULL COMMENT '阵型顺序（0 基）',
  `plant_id` VARCHAR(32) NOT NULL COMMENT '植物 id（外键 → plants.id）',
  `col` TINYINT NOT NULL COMMENT '列（0~8，网格 COLS=9）',
  `row` TINYINT NOT NULL COMMENT '行（0~4，网格 ROWS=5）',
  `hp` INT NOT NULL DEFAULT 0 COMMENT '当前生命',
  `state` JSON COMMENT '植物私有状态（结构随植物类型而变，对应 snapshot_state()）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_save_plant_seq` (`save_id`, `seq`),
  CONSTRAINT `fk_run_save_plants_save_id` FOREIGN KEY (`save_id`) REFERENCES `run_saves` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_run_save_plants_plant_id` FOREIGN KEY (`plant_id`) REFERENCES `plants` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 GridManager.to_snapshot() 的单元项（最多 45 个）。';

CREATE TABLE IF NOT EXISTS `run_save_zombies` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `save_id` BIGINT NOT NULL COMMENT '所属存档',
  `seq` INT NOT NULL COMMENT '出场顺序（0 基）',
  `zombie_id` VARCHAR(32) NOT NULL COMMENT '僵尸类型 id（外键 → zombies.id）',
  `row` TINYINT NOT NULL COMMENT '所在行（0~4）',
  `x` DECIMAL(10,3) NOT NULL DEFAULT 0.000 COMMENT '世界坐标 x',
  `hp` INT NOT NULL DEFAULT 0 COMMENT '当前生命',
  `has_hat` TINYINT NOT NULL DEFAULT FALSE COMMENT '是否仍持有顶具',
  `hat_hp` INT NOT NULL DEFAULT 0 COMMENT '顶具剩余生命',
  `state` TINYINT NOT NULL DEFAULT 0 COMMENT '状态机：0=Walk，1=Eat（瞬态不入档）',
  `slow_t` DECIMAL(8,3) NOT NULL DEFAULT 0.000 COMMENT '剩余减速时长（秒）',
  `bite_t` DECIMAL(8,3) NOT NULL DEFAULT 0.000 COMMENT '下次啃食倒计时（秒）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_save_zombie_seq` (`save_id`, `seq`),
  CONSTRAINT `fk_run_save_zombies_save_id` FOREIGN KEY (`save_id`) REFERENCES `run_saves` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_run_save_zombies_zombie_id` FOREIGN KEY (`zombie_id`) REFERENCES `zombies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 ZombieBase.to_snapshot()（最多 200 个）。';

CREATE TABLE IF NOT EXISTS `run_save_mowers` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `save_id` BIGINT NOT NULL COMMENT '所属存档',
  `row` TINYINT NOT NULL COMMENT '所在行（0~4，每行一个）',
  `used` TINYINT NOT NULL DEFAULT FALSE COMMENT '是否已使用',
  `running` TINYINT NOT NULL DEFAULT FALSE COMMENT '是否正在冲出',
  `x` DECIMAL(10,3) NOT NULL DEFAULT 0.000 COMMENT '世界坐标 x',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_save_mower_row` (`save_id`, `row`),
  CONSTRAINT `fk_run_save_mowers_save_id` FOREIGN KEY (`save_id`) REFERENCES `run_saves` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 LawnMower.to_snapshot()（固定 5 条，与 ROWS=5 对应）。';

CREATE TABLE IF NOT EXISTS `level_wave_zombies` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `wave_id` BIGINT NOT NULL COMMENT '所属波次',
  `seq` INT NOT NULL COMMENT '波内顺序（0 基）',
  `zombie_id` VARCHAR(32) NOT NULL COMMENT '僵尸类型 id（外键 → zombies.id）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_wave_zombie_seq` (`wave_id`, `seq`),
  CONSTRAINT `fk_level_wave_zombies_wave_id` FOREIGN KEY (`wave_id`) REFERENCES `level_waves` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_level_wave_zombies_zombie_id` FOREIGN KEY (`zombie_id`) REFERENCES `zombies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 waves[].z 数组（每波 1~20 只）。';

CREATE TABLE IF NOT EXISTS `run_save_pending_spawns` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  `wave_state_id` BIGINT NOT NULL COMMENT '所属波次状态',
  `seq` INT NOT NULL COMMENT '队列顺序（0 基）',
  `dt` DECIMAL(8,3) NOT NULL COMMENT '相对当前时刻的剩余秒数',
  `zombie_id` VARCHAR(32) NOT NULL COMMENT '僵尸类型 id（外键 → zombies.id）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pending_seq` (`wave_state_id`, `seq`),
  CONSTRAINT `fk_run_save_pending_spawns_wave_state_id` FOREIGN KEY (`wave_state_id`) REFERENCES `run_save_wave_states` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_run_save_pending_spawns_zombie_id` FOREIGN KEY (`zombie_id`) REFERENCES `zombies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对应 WaveSnapshot.pending（最多 20 条）。';


SET FOREIGN_KEY_CHECKS = 1;
