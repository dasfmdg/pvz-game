extends Node2D
## 启动入口：装配游戏主控，负责场景级生命周期
## 参考工程对应：main_scene 注册 + 主游戏管理器装配

var game: MainGameManager = null


func _ready() -> void:
	game = MainGameManager.new()
	add_child(game)