class_name ZombieFactory
extends RefCounted
## 僵尸工厂：按僵尸 id 生产对应实体（对应 PlantFactory，默认回退基类僵尸）

static func create(zombie_id: String) -> ZombieBase:
	match zombie_id:
		"pole":
			return ZombiePole.new()
		"newspaper":
			return ZombieNewspaper.new()
	return ZombieBase.new()
