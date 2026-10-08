-- Группы статей (схема drift 4, packages/local_db/lib/src/tables/
-- finance_tables.dart, FinCategoryGroups): справочник групп и ссылка на
-- группу у статьи. `fin_categories.group_name` остаётся — это копия названия
-- для программ 1.18 (они знают группу только текстом). Статьи без ссылки
-- сервер привязывает сам при запуске (CategoryGroups.linkAll) — так данные
-- попадают в журнал изменений и доходят до программ.
-- Сверку с клиентом делает test/schema_test.dart.
--
-- Добавляет таблицу и колонку (NULL); существующие данные не меняются.

CREATE TABLE fin_category_groups (
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legacy_id INT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  edited_by VARCHAR(64) NULL,
  type VARCHAR(16) NOT NULL,
  name VARCHAR(255) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  hidden TINYINT(1) NOT NULL DEFAULT 0,
  not_deleted TINYINT AS (IF(deleted = 0, 1, NULL)) VIRTUAL,
  PRIMARY KEY (uuid),
  UNIQUE KEY idx_fin_category_groups_name (type, name, not_deleted),
  CHECK (deleted IN (0, 1)),
  CHECK (hidden IN (0, 1)),
  CHECK (type IN ('income', 'expense'))
);

ALTER TABLE fin_categories
  ADD COLUMN group_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  ADD CONSTRAINT fk_fin_categories_group
    FOREIGN KEY (group_uuid) REFERENCES fin_category_groups (uuid);
