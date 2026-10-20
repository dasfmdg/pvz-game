#!/usr/bin/env python3
"""把 pvz_game.dbml 编译为 MySQL 8.0 建表 DDL（backend/db/schema.sql）。

为什么自研而不是用现成工具（已实测）：
- `pydbml` 解析不了本文件的负数默认值（`default: -1.000`），直接抛 ParseException；
- 官方 `@dbml/cli` 的 `dbml2sql` 在本文件上内部崩溃、无任何输出。

因此这里只实现本工程实际用到的 DBML 子集（`Table` / `Enum` / `Ref` / `indexes` / `Note`），
让 `pvz_game.dbml` 保持**唯一 schema 事实来源**，生成过程离线、可重复、零外部依赖。

用法：
    python backend/db/generate_schema.py            # 生成 backend/db/schema.sql
    python backend/db/generate_schema.py --check    # 只校验生成结果与磁盘文件是否一致
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

DBML_PATH = pathlib.Path(__file__).resolve().parents[2] / "pvz_game.dbml"
OUTPUT_PATH = pathlib.Path(__file__).resolve().parent / "schema.sql"

# MySQL 8.0 中必须加反引号的保留字列名
RESERVED_COLUMNS = {"row", "rank", "key", "values", "order", "group", "system", "lead", "lag"}

ENUM_NAME_RE = re.compile(r"^Enum\s+(\w+)\s*\{$")
TABLE_RE = re.compile(r"^Table\s+(\w+)\s*(?:\[(.*)\])?\s*\{$")
COLUMN_RE = re.compile(r"^(\w+)\s+([A-Za-z_][\w]*(?:\([\d,]+\))?)\s*(?:\[(.*)\])?\s*$")
INDEX_RE = re.compile(r"^\(([^)]*)\)\s*\[(.*)\]\s*$")
REF_RE = re.compile(r"^Ref:\s+(\w+)\.(\w+)\s+([<>-])\s+(\w+)\.(\w+)\s*(?:\[(.*)\])?\s*$")
NOTE_RE = re.compile(r"^Note:\s*'(.*)'\s*$")
FLAG_RE = re.compile(r"^(\w+)\s*:\s*(.*)$")


class DbmlError(Exception):
    """DBML 中出现生成器无法识别的语法时抛出（宁可报错，不静默跳过）。"""


def _strip_comment(raw: str) -> str:
    """去掉行内 `//` 注释，但尊重单引号包裹的文本（note 中可能出现 `res://` 资源路径）。"""
    in_quotes = False
    index = 0
    while index < len(raw):
        char = raw[index]
        if char == "'":
            in_quotes = not in_quotes
        elif char == "/" and not in_quotes and raw.startswith("//", index):
            return raw[:index]
        index += 1
    return raw


def _split_flags(raw: str) -> dict[str, str | None]:
    """把 `[pk, increment, default: 0.800, note: '...']` 拆成 {flag: value}。

    note 值里可能含逗号，因此按"顶层逗号"切分（尊重单引号包裹）。
    """
    parts: list[str] = []
    buffer = ""
    in_quotes = False
    for char in raw:
        if char == "'":
            in_quotes = not in_quotes
        if char == "," and not in_quotes:
            parts.append(buffer)
            buffer = ""
            continue
        buffer += char
    parts.append(buffer)

    flags: dict[str, str | None] = {}
    for part in parts:
        item = part.strip()
        if not item:
            continue
        matched = FLAG_RE.match(item)
        if matched:
            flags[matched.group(1)] = matched.group(2).strip()
        else:
            flags[item] = None
    return flags


def _unquote(value: str | None) -> str | None:
    if value is None:
        return None
    text = value.strip()
    if len(text) >= 2 and text[0] == "'" and text[-1] == "'":
        return text[1:-1]
    return text


def _sql_ident(name: str) -> str:
    return f"`{name}`"


def _sql_literal(text: str) -> str:
    return "'" + text.replace("\\", "\\\\").replace("'", "''") + "'"


class Column:
    def __init__(self, table: str, name: str, dbml_type: str, flags: dict[str, str | None]) -> None:
        self.table = table
        self.name = name
        self.dbml_type = dbml_type
        self.is_pk = "pk" in flags
        self.is_increment = "increment" in flags
        self.is_unique = "unique" in flags
        self.not_null = "not null" in flags or self.is_pk
        self.default = _unquote(flags.get("default"))
        self.note = _unquote(flags.get("note"))


class Index:
    def __init__(self, columns: list[str], flags: dict[str, str | None]) -> None:
        self.columns = columns
        self.unique = "unique" in flags
        self.name = _unquote(flags.get("name"))


class Table:
    def __init__(self, name: str, note: str | None) -> None:
        self.name = name
        self.note = note
        self.columns: list[Column] = []
        self.indexes: list[Index] = []


class ForeignKey:
    def __init__(self, child_table: str, child_column: str, parent_table: str, parent_column: str, on_delete: bool) -> None:
        self.child_table = child_table
        self.child_column = child_column
        self.parent_table = parent_table
        self.parent_column = parent_column
        self.on_delete_cascade = on_delete


class Schema:
    def __init__(self) -> None:
        self.enums: dict[str, list[str]] = {}
        self.tables: list[Table] = []
        self.foreign_keys: list[ForeignKey] = []


def parse_dbml(text: str) -> Schema:
    schema = Schema()
    lines = text.splitlines()
    table: Table | None = None
    in_indexes = False
    in_enum: str | None = None

    for number, raw in enumerate(lines, start=1):
        line = _strip_comment(raw).strip()
        if not line:
            continue

        if in_enum is not None:
            if line == "}":
                in_enum = None
            else:
                schema.enums[in_enum].append(line)
            continue

        enum_match = ENUM_NAME_RE.match(line)
        if enum_match:
            in_enum = enum_match.group(1)
            schema.enums[in_enum] = []
            continue

        ref_match = REF_RE.match(line)
        if ref_match:
            child_table, child_column, _operator, parent_table, parent_column, ref_flags = ref_match.groups()
            flags = _split_flags(ref_flags) if ref_flags else {}
            schema.foreign_keys.append(
                ForeignKey(child_table, child_column, parent_table, parent_column, "delete" in flags)
            )
            continue

        table_match = TABLE_RE.match(line)
        if table_match:
            flags = _split_flags(table_match.group(2)) if table_match.group(2) else {}
            table = Table(table_match.group(1), _unquote(flags.get("note")))
            schema.tables.append(table)
            in_indexes = False
            continue

        if table is None:
            raise DbmlError(f"第 {number} 行出现在任何 Table 之外：{raw}")

        if line == "indexes {":
            in_indexes = True
            continue

        if in_indexes:
            if line == "}":
                in_indexes = False
                continue
            index_match = INDEX_RE.match(line)
            if not index_match:
                raise DbmlError(f"第 {number} 行无法解析为索引：{raw}")
            columns = [part.strip().strip("`") for part in index_match.group(1).split(",")]
            table.indexes.append(Index(columns, _split_flags(index_match.group(2))))
            continue

        if line == "}":
            table = None
            continue

        if line.startswith("Note:"):
            dot_match = NOTE_RE.match(line)
            if not dot_match:
                raise DbmlError(f"第 {number} 行无法解析为 Note：{raw}")
            table.note = dot_match.group(1)
            continue

        column_match = COLUMN_RE.match(line)
        if not column_match:
            raise DbmlError(f"第 {number} 行无法解析为列定义：{raw}")
        flags = _split_flags(column_match.group(3)) if column_match.group(3) else {}
        table.columns.append(Column(table.name, column_match.group(1), column_match.group(2), flags))

    return schema


def render_column_type(dbml_type: str, enums: dict[str, list[str]]) -> str:
    if dbml_type in enums:
        values = ", ".join(_sql_literal(value) for value in enums[dbml_type])
        return f"ENUM({values})"
    if dbml_type == "json":
        return "JSON"
    if dbml_type == "datetime":
        return "DATETIME"
    return dbml_type.upper()


def render_default(value: str, dbml_type: str) -> str:
    if value.startswith("`") and value.endswith("`"):
        # 反引号包裹表示原始 SQL 表达式
        expression = value[1:-1]
        if expression.lower().startswith("current_timestamp"):
            return "DEFAULT CURRENT_TIMESTAMP"
        return f"DEFAULT {expression}"
    if value.lower() == "true":
        return "DEFAULT TRUE"
    if value.lower() == "false":
        return "DEFAULT FALSE"
    if re.match(r"^-?\d+(\.\d+)?$", value):
        return f"DEFAULT {value}"
    return f"DEFAULT {_sql_literal(value)}"


def render_table(table: Table, schema: Schema) -> str:
    lines: list[str] = []
    for column in table.columns:
        name = _sql_ident(column.name)
        piece = f"  {name} {render_column_type(column.dbml_type, schema.enums)}"
        if column.not_null:
            piece += " NOT NULL"
        if column.default is not None:
            piece += " " + render_default(column.default, column.dbml_type)
        if column.is_increment:
            piece += " AUTO_INCREMENT"
        if column.note:
            piece += f" COMMENT {_sql_literal(column.note)}"
        lines.append(piece)

    primary = [column.name for column in table.columns if column.is_pk]
    if primary:
        lines.append("  PRIMARY KEY (" + ", ".join(_sql_ident(name) for name in primary) + ")")

    for column in table.columns:
        if column.is_unique and not column.is_pk:
            lines.append(f"  UNIQUE KEY {_sql_ident('uk_' + table.name + '_' + column.name)} ({_sql_ident(column.name)})")

    for index in table.indexes:
        keyword = "UNIQUE KEY" if index.unique else "KEY"
        index_name = index.name or f"idx_{table.name}_{'_'.join(index.columns)}"
        columns = ", ".join(_sql_ident(name) for name in index.columns)
        lines.append(f"  {keyword} {_sql_ident(index_name)} ({columns})")

    # 外键内联在建表语句里：配合 CREATE TABLE IF NOT EXISTS，整份 DDL 天然幂等
    # （若改用末尾 ALTER TABLE ADD CONSTRAINT，重复执行会撞 Duplicate foreign key constraint）
    for foreign_key in schema.foreign_keys:
        if foreign_key.child_table != table.name:
            continue
        name = f"fk_{foreign_key.child_table}_{foreign_key.child_column}"
        piece = (
            f"  CONSTRAINT {_sql_ident(name)}"
            f" FOREIGN KEY ({_sql_ident(foreign_key.child_column)})"
            f" REFERENCES {_sql_ident(foreign_key.parent_table)} ({_sql_ident(foreign_key.parent_column)})"
        )
        if foreign_key.on_delete_cascade:
            piece += " ON DELETE CASCADE"
        lines.append(piece)

    suffix = ",\n".join(lines)
    statement = (
        f"CREATE TABLE IF NOT EXISTS {_sql_ident(table.name)} (\n{suffix}\n)"
        " ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    )
    if table.note:
        statement += f" COMMENT={_sql_literal(table.note)}"
    return statement + ";"


def order_tables(schema: Schema) -> list[Table]:
    """按外键依赖拓扑排序，保证被引用表先建（外键内联的前提）。"""
    by_name = {table.name: table for table in schema.tables}
    dependencies = {
        table.name: {
            foreign_key.parent_table
            for foreign_key in schema.foreign_keys
            if foreign_key.child_table == table.name and foreign_key.parent_table != table.name
        }
        for table in schema.tables
    }
    ordered: list[Table] = []
    placed: set[str] = set()
    remaining = [table.name for table in schema.tables]
    while remaining:
        batch = [name for name in remaining if dependencies[name] <= placed]
        if not batch:
            raise DbmlError(f"外键存在循环依赖，无法拓扑排序：{sorted(remaining)}")
        for name in batch:
            ordered.append(by_name[name])
            placed.add(name)
            remaining.remove(name)
    return ordered


def render(schema: Schema) -> str:
    header = [
        "-- ============================================================================",
        "-- pvz-game 物理库结构 · MySQL 8.0 建表 DDL",
        "--",
        "-- 本文件由 backend/db/generate_schema.py 从 pvz_game.dbml 生成，请勿手工编辑。",
        "-- 事实来源：pvz_game.dbml（DBML）→ 本文件（DDL）→ 实际数据库 → SQLAlchemy 反射。",
        "-- 重新生成：python backend/db/generate_schema.py",
        "-- ============================================================================",
        "",
        "SET NAMES utf8mb4;",
        "SET FOREIGN_KEY_CHECKS = 0;",
        "",
        "-- --------------------------- 枚举（以 MySQL ENUM 落地） ---------------------------",
    ]
    for name, values in schema.enums.items():
        header.append(f"--   {name}: " + " / ".join(values))
    header.append("")

    body: list[str] = [
        "-- --------------------------- 建表 ---------------------------",
        f"-- 共 {len(schema.tables)} 表 / {len(schema.foreign_keys)} 外键（外键内联，按依赖顺序排列，整份 DDL 幂等）",
        "",
    ]
    for table in order_tables(schema):
        body.append(render_table(table, schema))
        body.append("")

    footer = ["", "SET FOREIGN_KEY_CHECKS = 1;", ""]
    return "\n".join(header + body + footer)


def main() -> int:
    parser = argparse.ArgumentParser(description="从 pvz_game.dbml 生成 MySQL 建表 DDL")
    parser.add_argument("--check", action="store_true", help="只校验磁盘上的 schema.sql 与当前 DBML 是否一致")
    options = parser.parse_args()

    schema = parse_dbml(DBML_PATH.read_text(encoding="utf-8"))
    generated = render(schema)

    if options.check:
        if not OUTPUT_PATH.exists():
            print(f"FAIL: {OUTPUT_PATH} 不存在，请先运行 generate_schema.py")
            return 1
        current = OUTPUT_PATH.read_text(encoding="utf-8")
        if current != generated:
            print("FAIL: schema.sql 与 pvz_game.dbml 不一致，请重新生成")
            return 1
        print(f"OK: schema.sql 与 pvz_game.dbml 一致（{len(schema.tables)} 表 / {len(schema.foreign_keys)} 外键）")
        return 0

    OUTPUT_PATH.write_text(generated, encoding="utf-8")
    print(
        f"已生成 {OUTPUT_PATH}：{len(schema.tables)} 表 / "
        f"{len(schema.enums)} 枚举 / {len(schema.foreign_keys)} 外键"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
