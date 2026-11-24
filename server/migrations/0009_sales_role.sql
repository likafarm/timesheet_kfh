-- Роль «специалист по продажам» (этап 11.2): `sales` в ограничении роли
-- пользователя. Ограничение из 0001 безымянное — MySQL назвал его
-- users_chk_1 (первое CHECK таблицы users); заменяется именованным.
--
-- Данные не меняются.

ALTER TABLE users DROP CHECK users_chk_1;
ALTER TABLE users
  ADD CONSTRAINT chk_users_role
    CHECK (role IN ('admin', 'accountant', 'operator', 'sales'));
