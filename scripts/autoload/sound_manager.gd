extends Node
## 音效管理：WebAudio 时代改为直接播放 WAV 资源，玩家对象池复用，避免频繁创建节点

const SOUNDS := {
	"zombies_are_coming": "res://assets/sounds/zombies_are_coming.wav",
	"yuck": "res://assets/sounds/yuck.wav",
	"splat3": "res://assets/sounds/splat3.wav",
	"plant": "res://assets/sounds/plant.wav",
	"lawnmower": "res://assets/sounds/lawnmower.wav",
	"jalapeno": "res://assets/sounds/jalapeno.wav",
	"groan": "res://assets/sounds/groan.wav",
	"chomp": "res://assets/sounds/chomp.wav",
	"cherrybomb": "res://assets/sounds/cherrybomb.wav",
	"brainz": "res://assets/sounds/brainz.wav",
}

const BGM_PATH := "res://assets/sounds/background.wav"
const POOL_SIZE := 8
const SFX_VOLUME_DB := -6.0
const BGM_VOLUME_DB := -16.0

var is_muted := false
var bgm_volume := 1.0
var sfx_volume := 1.0

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _bgm_player: AudioStreamPlayer
## 是否已经过用户手势（启动页点击）允许起播；Web 端自动播放策略要求音频由手势触发
var _bgm_armed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key: String in SOUNDS.keys():
		var stream: AudioStream = load(String(SOUNDS[key])) as AudioStream
		if stream != null:
			_streams[key] = stream
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.volume_db = SFX_VOLUME_DB
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)
	_setup_bgm()


func _setup_bgm() -> void:
	var bgm := load(BGM_PATH) as AudioStream
	if bgm == null:
		return
	if bgm is AudioStreamWAV:
		(bgm as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.stream = bgm
	_bgm_player.volume_db = BGM_VOLUME_DB
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player)


## 播放一次音效；音效名不存在时静默忽略，不阻断游戏
func play(sound: String) -> void:
	if is_muted or not _streams.has(sound):
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _streams[sound]
	player.play()


## 起播全局 BGM：在启动页点击（用户手势）后调用一次，之后菜单/选关/图鉴/关卡全程循环
## 静音时不出声，但同样记录已具备起播条件，取消静音后由 _refresh_bgm 自动续上
func play_bgm() -> void:
	_bgm_armed = true
	_refresh_bgm()


## BGM 是否已具备起播条件（已收到过用户手势）；供校验与排查使用
func is_bgm_armed() -> bool:
	return _bgm_armed


## 按当前静音状态同步 BGM：未起播则起播，已起播则暂停/恢复
func _refresh_bgm() -> void:
	if not _bgm_armed or _bgm_player == null:
		return
	if is_muted:
		if _bgm_player.playing:
			_bgm_player.stream_paused = true
		return
	if _bgm_player.playing:
		_bgm_player.stream_paused = false
		return
	_bgm_player.play()


func stop_bgm() -> void:
	if _bgm_player != null:
		_bgm_player.stop()


func set_muted(muted: bool) -> void:
	is_muted = muted
	if muted:
		for player in _players:
			player.stop()
	_refresh_bgm()
	EventBus.sound_muted.emit(is_muted)


func toggle_mute() -> void:
	set_muted(not is_muted)


## 设置 BGM 音量（线性 0.0~1.0），实时作用于播放器
func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	if _bgm_player != null:
		_bgm_player.volume_db = BGM_VOLUME_DB + _to_db(bgm_volume)


## 设置音效音量（线性 0.0~1.0），实时作用于对象池
func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	var db := SFX_VOLUME_DB + _to_db(sfx_volume)
	for player in _players:
		player.volume_db = db


## 线性音量 → 分贝；0 时钳制到 -80dB，避免 -inf
func _to_db(value: float) -> float:
	return linear_to_db(value) if value > 0.001 else -80.0