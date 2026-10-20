"""数据库接入层：pvz_game.dbml → backend/db/schema.sql → 真实 MySQL → SQLAlchemy 反射。

本包的定位：让 `pvz_game.dbml` 成为唯一 schema 事实来源，Python 侧不维护第二份表结构定义
（表 / 列 / 类型全部通过反射取自真实库，反射结果与 schema.sql 由构建期保证一致）。
"""
