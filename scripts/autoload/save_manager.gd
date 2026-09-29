extends Node
## 存档管理：设置（音量/静音）与进度（已通关关卡 / 最佳击杀 / 解锁进度）
## 落盘 user://pvz_save.json；读取失败或文件缺失时回退默认值，绝不抛错阻断游戏

const SAVE_PATH := "user://pvz_save.json"

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
	_read_settings(parsed as Dictionary)
	_read_progress(parsed as Dictionary)
	_apply_settings()


## 写入存档；写盘失败仅告警，不阻断游戏
func save() -> void:
	var data := {
		"bgm_volume": bgm_volume,
		"sfx_volume": sfx_volume,
		"muted": muted,
		"cleared_levels": cleared_levels,
		"best_kills": best_kills,
		"unlocked_level": unlocked_level,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveManager] 存档写入失败：%s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


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
	var raw_levels: Variant = data.get("cleared_levels", [])
	if raw_levels is Array:
		for raw in raw_levels:
			var level_index := int(raw)
			if not cleared_levels.has(level_index):
				cleared_levels.append(level_index)
	best_kills = {}
	var raw_kills: Variant = data.get("best_kills", {})
	if raw_kills is Dictionary:
		for key in (raw_kills as Dictionary).keys():
			best_kills[int(key)] = int((raw_kills as Dictionary)[key])
	unlocked_level = maxi(0, int(data.get("unlocked_level", 0)))


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