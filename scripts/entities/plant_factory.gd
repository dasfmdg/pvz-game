class_name PlantFactory
extends RefCounted
## 植物工厂：按植物 id 生产对应实体（对应参考工程的 AllCards 注册表）

static func create(plant_id: String) -> PlantBase:
	match plant_id:
		"sunflower":
			return PlantSunflower.new()
		"peashooter", "repeater", "snowpea", "threepeater":
			return PlantShooter.new()
		"wallnut":
			return PlantWallnut.new()
		"cherrybomb", "jalapeno":
			return PlantBomb.new()
		"potato_mine":
			return PlantPotatoMine.new()
		"squash":
			return PlantSquash.new()
		"chomper":
			return PlantChomper.new()
	push_warning("[PlantFactory] 未知植物 id：%s" % plant_id)
	return null