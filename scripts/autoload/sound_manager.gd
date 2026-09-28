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

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _bgm_player: AudioStreamPlayer


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


func play_bgm() -> void:
	if is_muted or _bgm_player == null:
		return
	if not _bgm_player.playing:
		_bgm_player.play()


func stop_bgm() -> void:
	if _bgm_player != null:
		_bgm_player.stop()


func set_muted(muted: bool) -> void:
	is_muted = muted
	if _bgm_player != null:
		_bgm_player.stream_paused = muted
	if muted:
		for player in _players:
			player.stop()
	EventBus.sound_muted.emit(is_muted)


func toggle_mute() -> void:
	set_muted(not is_muted)
	if not is_muted:
		play_bgm()