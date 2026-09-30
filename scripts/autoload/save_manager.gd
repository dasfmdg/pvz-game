extends Node
## 存档管理：设置（音量/静音）与进度（已通关关卡 / 最佳击杀 / 解锁进度）
## 落盘 user://pvz_save.json；读取失败或文件缺失时回退默认值，绝不抛错阻断游戏
## 结构：v2 = {"version":2, "settings":{...}, "progress":{unlocked_level, levels:{"<关卡号>":{cleared, best_kills}}}}
##       v1 = 扁平字段（bgm_volume / cleared_levels / best_kills / unlocked_level），读入后自动升级为 v2

const SAVE_PATH := "user://pvz_save.json"

## 存档结构版本：1 = 旧扁平字段，2 = settings / progress 分区 + 分关进度表
const SAVE_VERSION := 2

## 单局快照槽位：独立落盘 user://pvz_run_save_<slot>.json，与设置/进度存档互不影响
const RUN_SLOT_MIN := 1
const RUN_SLOT_MAX := 3
## 单局快照结构版本（与 MainGameManager.SNAPSHOT_VERSION 对应）
const RUN_SAVE_VERSION := 1

const DEFAULT_BGM_VOLUME := 0.8
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_MUTED := false

var bgm_volume := DEFAULT_BGM_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
var muted := DEFAULT_MUTED

var cleared_levels: Array[int] = []
var best_kills: Dictionary = {}
var unlocked_level := 0


func _ready() -> void:
	load_save()


# ---------------- 读写 ----------------
## 载入存档；任何异常都会回退到默认值
func load_save() -> void:
	_reset_to_defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		_apply_settings()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[SaveManager] 存档打开失败，使用默认值：%s" % SAVE_PATH)
		_apply_settings()
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Dictionary:
		push_warning("[SaveManager] 存档解析失败，使用默认值")
		_apply_settings()
		return
	_read_root(parsed as Dictionary)
	_apply_settings()


## 兼容读取：v2 走 settings / progress 分区，v1（无 version 或旧扁平结构）逐字段读入后升级落盘
func _read_root(root: Dictionary) -> void:
	var settings: Variant = root.get("settings", null)
	var progress: Variant = root.get("progress", null)
	if int(root.get("version", 1)) >= SAVE_VERSION \
			and settings is Dictionary and progress is Dictionary:
		_read_settings(settings as Dictionary)
		_read_progress(progress as Dictionary)
		return
	_read_settings(root)
	_read_progress(root)
	save()   # 旧结构迁移为 v2，只写新结构


## 写入存档；写盘失败仅告警，不阻断游戏
func save() -> void:
	var data := {
		"version": SAVE_VERSION,
		"settings": {
			"bgm_volume": bgm_volume,
			"sfx_volume": sfx_volume,
			"muted": muted,
		},
		"progress": {
			"unlocked_level": unlocked_level,
			"levels": _levels_to_dict(),
		},
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveManager] 存档写入失败：%s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## 进度按关卡号归并为 {"<关卡号>": {cleared, best_kills}}
func _levels_to_dict() -> Dictionary:
	var levels := {}
	for key in best_kills.keys():
		var index := int(key)
		var kills := int(best_kills[key])
		if kills <= 0:
			continue
		levels[str(index)] = {"cleared": cleared_levels.has(index), "best_kills": kills}
	for level_index in cleared_levels:
		if not levels.has(str(level_index)):
			levels[str(level_index)] = {"cleared": true, "best_kills": 0}
	return levels


func _reset_to_defaults() -> void:
	bgm_volume = DEFAULT_BGM_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	muted = DEFAULT_MUTED
	cleared_levels = []
	best_kills = {}
	unlocked_level = 0


func _read_settings(data: Dictionary) -> void:
	bgm_volume = clampf(float(data.get("bgm_volume", DEFAULT_BGM_VOLUME)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", DEFAULT_SFX_VOLUME)), 0.0, 1.0)
	muted = bool(data.get("muted", DEFAULT_MUTED))


func _read_progress(data: Dictionary) -> void:
	cleared_levels = []
	best_kills = {}
	unlocked_level = 0
	var levels: Variant = data.get("levels", null)
	if levels is Dictionary:
		_read_levels(levels as Dictionary)
	else:
		_read_legacy_progress(data)
	unlocked_level = clampi(int(data.get("unlocked_level", 0)), 0,
			maxi(GameConfig.LEVELS.size() - 1, 0))


## v2：分关进度表 {"<关卡号>": {cleared, best_kills}}
func _read_levels(levels: Dictionary) -> void:
	for key in levels.keys():
		var level_index := int(str(key))
		var entry: Variant = levels[key]
		if entry is not Dictionary:
			continue
		var info := entry as Dictionary
		if bool(info.get("cleared", false)) and not cleared_levels.has(level_index):
			cleared_levels.append(level_index)
		var kills := int(info.get("best_kills", 0))
		if kills > 0:
			best_kills[level_index] = kills


## v1：扁平字段（cleared_levels 数组 + best_kills 字典）
func _read_legacy_progress(data: Dictionary) -> void:
	var raw_levels: Variant = data.get("cleared_levels", [])
	if raw_levels is Array:
		for raw in raw_levels:
			var level_index := int(raw)
			if not cleared_levels.has(level_index):
				cleared_levels.append(level_index)
	var raw_kills: Variant = data.get("best_kills", {})
	if raw_kills is Dictionary:
		for key in (raw_kills as Dictionary).keys():
			best_kills[int(key)] = int((raw_kills as Dictionary)[key])


## 把当前设置同步到 SoundManager（音量 / 静音）
func _apply_settings() -> void:
	if SoundManager == null:
		return
	SoundManager.set_bgm_volume(bgm_volume)
	SoundManager.set_sfx_volume(sfx_volume)
	SoundManager.set_muted(muted)


# ---------------- 对外接口 ----------------
## 修改设置项并立即持久化（支持 bgm_volume / sfx_volume / muted）
func set_setting(key: String, value: Variant) -> void:
	match key:
		"bgm_volume":
			bgm_volume = clampf(float(value), 0.0, 1.0)
			SoundManager.set_bgm_volume(bgm_volume)
		"sfx_volume":
			sfx_volume = clampf(float(value), 0.0, 1.0)
			SoundManager.set_sfx_volume(sfx_volume)
		"muted":
			muted = bool(value)
			SoundManager.set_muted(muted)
		_:
			return
	save()


## 通关记录：解锁下一关并刷新最佳击杀
func mark_cleared(level_index: int, kills: int) -> void:
	if not cleared_levels.has(level_index):
		cleared_levels.append(level_index)
	best_kills[level_index] = maxi(int(best_kills.get(level_index, 0)), kills)
	unlocked_level = mini(maxi(unlocked_level, level_index + 1), GameConfig.LEVELS.size() - 1)
	save()


func is_unlocked(index: int) -> bool:
	return index >= 0 and index <= unlocked_level


func is_cleared(index: int) -> bool:
	return cleared_levels.has(index)


func best_kills_of(index: int) -> int:
	return int(best_kills.get(index, 0))


## 累计最佳击杀（全通关结算统计用）
func total_best_kills() -> int:
	var total := 0
	for key in best_kills.keys():
		total += int(best_kills[key])
	return total


# ---------------- 单局快照槽位 ----------------
## 槽位夹取到 1~3，越界输入自动归位，避免脏路径
func _run_save_path(slot: int) -> String:
	return "user://pvz_run_save_%d.json" % clampi(slot, RUN_SLOT_MIN, RUN_SLOT_MAX)


## 写入单局快照；写盘失败仅告警并返回 false，绝不抛错打断游戏
func save_run(slot: int, data: Dictionary) -> bool:
	var path := _run_save_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveManager] 单局快照写入失败：%s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


## 读取单局快照；无档 / 打开失败 / 解析失败 / 版本不匹配一律返回空字典
func load_run(slot: int) -> Dictionary:
	var path := _run_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[SaveManager] 单局快照打开失败：%s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Dictionary:
		push_warning("[SaveManager] 单局快照解析失败：%s" % path)
		return {}
	var root := parsed as Dictionary
	if int(root.get("version", 0)) != RUN_SAVE_VERSION:
		push_warning("[SaveManager] 单局快照版本不匹配：%s" % path)
		return {}
	return root


## 槽位是否存在可用快照（文件缺失 / 内容损坏视为无档）
func has_run(slot: int) -> bool:
	var path := _run_save_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text) is Dictionary


## 删除槽位快照；文件不存在时静默返回
func remove_run(slot: int) -> void:
	var path := _run_save_path(slot)
	if not FileAccess.file_exists(path):
		return
	var err := DirAccess.remove_absolute(path)
	if err != OK:
		push_warning("[SaveManager] 单局快照删除失败（err=%d）：%s" % [err, path])