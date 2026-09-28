# Сервер КФХ (`kfh_server`)

API синхронизации и отчётов поверх MySQL. Чистый Dart (`shelf`), расчёт ЗП —
общий пакет `kfh_domain`. Пакет входит в Dart workspace репозитория.

## Настройки (переменные окружения)

| Переменная | По умолчанию | Смысл |
|---|---|---|
| `PORT` | 8080 | порт HTTP |
| `DB_HOST`, `DB_NAME`, `DB_USER` | — (обязательны) | MySQL |
| `DB_PORT` | 3306 | порт MySQL |
| `DB_PASSWORD` / `DB_PASSWORD_FILE` | — (одно из двух) | пароль или путь к файлу с ним (Docker secrets) |
| `DB_SECURE` | true | TLS до MySQL |
| `DB_MAX_CONNECTIONS` | 10 | размер пула |

| `MIGRATIONS_DIR` | `migrations` | папка SQL-миграций (в образе — `/app/migrations`) |
| `MIGRATE_ON_START` | false | применять миграции при старте (только стенд) |
| `JWT_SECRET` / `JWT_SECRET_FILE` | — (для сервера обязателен) | ключ подписи access-токенов, ≥ 32 байт (`openssl rand -base64 48`) |
| `TRUST_PROXY` | false | за Caddy: адрес клиента — последний в `X-Forwarded-For` |
| `CLIENT_VERSIONS_FILE` | — | файл версий программ для `GET /client/version` (нет — обновлений не требуется) |
| `CORS_ORIGINS` | — | через запятую — адреса страниц, которым браузер разрешит обращаться к API (только отладка веб-версии: `http://localhost:5080`); на VPS не задавать |

Без обязательной переменной сервер не стартует (код выхода 78, причина — в журнале).

## Миграции

- Файлы `server/migrations/NNNN_имя.sql`, номера подряд с 0001. Команды делятся по `;`
  (строки и комментарии учитываются, процедур/`DELIMITER` нет).
- Применённые записываются в `schema_migrations` с sha256 текста (CRLF/LF не влияет).
  Правка применённой миграции — отказ старта: изменения — только новой миграцией.
- `server migrate` — применить недостающие и выйти; идёт под `GET_LOCK`, два запуска не мешают друг другу.
- Сервер без применённых миграций не стартует (кроме `MIGRATE_ON_START=true`);
  база с миграцией, которой нет в программе («база новее»), — тоже отказ.
- **DDL в MySQL не откатывается транзакцией.** Упавшая миграция не отмечается применённой, но база
  может остаться частично изменённой — поэтому перед `migrate` всегда резервная копия, откат — восстановление из неё.
- Схема повторяет клиентскую (`packages/local_db`), `test/schema_test.dart` сверяет состав полей, типы и
  NULL со снимком drift. Отличия: нет `remote_updated_at`; даты дней — `DATE`; частичная уникальность —
  через служебный столбец `not_deleted` (1/NULL); внешние ключи не отложенные.
- Все моменты времени — UTC: пул ставит `time_zone = '+00:00'` каждому соединению.
- Чтение `information_schema` — через `CAST(... AS CHAR)`: MySQL 8 отдаёт там двоичные строки.

## Локальный стенд (Docker Desktop)

```powershell
docker compose -f server/docker-compose.dev.yml up -d --build   # из корня репозитория
curl.exe http://localhost:8080/health
docker compose -f server/docker-compose.dev.yml logs api
docker compose -f server/docker-compose.dev.yml down            # данные MySQL сохраняются (down -v — удалить)
```

MySQL стенда доступна с этого ПК на `127.0.0.1:3307` (`kfh_api` / `dev-api`, root / `dev-root`).
Пароли — только для разработки.

Отладка веб-версии со стендом: `flutter run -d chrome --web-port 5080` (стенд разрешает CORS для
`http://localhost:5080`). Сборку как на VPS (`/app/` + API за Caddy) можно проверить боевым Caddyfile в сети
стенда: `docker run --rm --network kfh-dev_default -p 127.0.0.1:8093:8093 -e KFH_DOMAIN=http://localhost:8093
-v <репозиторий>/server/deploy/Caddyfile:/etc/caddy/Caddyfile:ro -v <репозиторий>/build/web:/srv/web/app:ro
caddy:2.10` после `flutter build web --release --base-href /app/ --no-web-resources-cdn`.

## Тесты

```powershell
cd server
dart test                                   # без MySQL (тесты с тегом mysql пропускаются)
$env:KFH_TEST_MYSQL="1"; dart test -t mysql # на стенде; хост/порт/учётка — KFH_TEST_DB_*
```

Тесты на MySQL создают себе отдельную базу `kfh_test_…` от root (`KFH_TEST_DB_ROOT_PASSWORD`, по умолчанию
пароль стенда) и удаляют её после себя.

## Команды образа

```powershell
docker compose -f server/docker-compose.dev.yml run --rm api migrate
docker compose -f server/docker-compose.dev.yml run --rm api create-admin <логин> "<ФИО>"   # пока админов нет
docker compose -f server/docker-compose.dev.yml run --rm api set-password <логин>          # из консоли сервера
```

Пароль команды спрашивают без эха (или читают первую строку stdin: `-T` и конвейер).

## Эндпоинты

- `GET /health` — 200 `{"status":"ok","version":"…","db":"ok"}`; если MySQL не отвечает за 3 с — 503.
- `POST /auth/login` `{login, password}` → `{access_token, access_expires_at, refresh_token, refresh_expires_at, user}`.
  Заголовок `X-Device-Id` (необязательный) пишется в токен и аудит.
- `POST /auth/refresh` `{refresh_token}` → новая пара; старый refresh гасится. Повторное предъявление погашенного
  refresh гасит всю цепочку этого входа (`token_reuse` в аудите).
- `POST /auth/logout` `{refresh_token}` → 204 (всегда).
- `GET /auth/me`, `POST /auth/change-password` `{old_password, new_password}` → новая пара, прочие входы гаснут.
- Только админ: `GET /users`, `POST /users` `{login, full_name, role, password}` → 201,
  `PATCH /users/<uuid>` `{full_name?, role?, is_active?}`, `POST /users/<uuid>/reset-password` `{password}` → 204.

Остальное — с `Authorization: Bearer <access_token>`. Коды ошибок для клиента:
`token_invalid` (401, обменять refresh), `session_expired` (401, войти заново), `invalid_credentials` (401),
`user_disabled` (403), `forbidden` (403), `password_change_required` (403 — пароль от админа, доступны только
`me`, `change-password`, `refresh`, `logout`), `too_many_attempts` (429, `Retry-After`), `login_taken`,
`self_change`, `last_admin` (409), `validation` (400), `too_large` (413).

## Синхронизация

Формат записи — `SyncChange` из `kfh_domain` (`packages/domain/lib/src/sync/`): полный снимок строки
`{change_id?, table, uuid, updated_at, deleted, data}`; `updated_at` — UTC ISO 8601 с `Z` до микросекунд,
`data` — ровно поля из `syncTables` (дни `гггг-мм-дд`, числа, `true/false`). Описание сверяется тестами и со
схемой клиента (`packages/local_db/test/sync_tables_test.dart`), и с MySQL (`test/schema_test.dart`).

- `POST /sync/push` `{changes: [...]}` (до 500, заголовок `X-Device-Id` обязателен — он же `edited_by`) →
  `{results: [{change_id, uuid, status, code?, message?, conflict_uuid?}]}` в порядке запроса.
  Статусы: `applied`; `duplicate` (та же версия уже есть — успех, повтор отправки безопасен); `stale`
  (на сервере новее или то же время с другими данными — побеждает сервер, клиент получит её pull'ом);
  `rejected` с кодом: `invalid`, `forbidden`, `period_locked`, `unique_conflict` (+ `conflict_uuid` живой
  записи того же дня/месяца), `unknown_employee`, `clock_skew` (время больше чем на 5 минут в будущем).
  Отказ одного изменения не мешает остальным (точка сохранения на каждое).
- `GET /sync/pull?cursor=&epoch=&limit=` (limit до 1000, по умолчанию 500) → `{epoch, cursor, has_more, changes}`.
  Запись, менявшаяся несколько раз, приходит один раз в текущем виде; удалённые — с `deleted: true`;
  сотрудники раньше ссылающихся записей. Первый раз — `cursor=0` без эпохи. Чужая эпоха или курсор за концом
  журнала — 409 `resync_required`: синхронизироваться с нуля.
- Очередь записи: каждая транзакция, пишущая в `change_log`, блокирует строку `sync_serial` (`ChangeLog.lock`)
  — порядок `seq` совпадает с порядком фиксации, pull не пропустит изменение. Новые писатели журнала
  (расчёт, импорт) обязаны делать так же.
- **После восстановления базы из копии** сменить эпоху: `UPDATE sync_serial SET epoch = UUID();` — иначе клиенты
  с курсором новее копии пропустят изменения.
- Права: оператор пишет только табель, читает сотрудников (ставки приходят нулями) и табель; бухгалтер и
  админ — всё. Смена роли на более широкую требует от клиента синхронизации с нуля (этап 3).
- Закрытые месяцы (`PeriodGuard` в `kfh_domain` — те же правила проверяет клиент): отклоняется изменение, задевающее закрытый месяц — день табеля, день выплаты,
  месяц расчёта, период больничного/отпуска/ставки. Если у ставки (больничного, отпуска) поменялись только
  границы, задетыми считаются лишь вошедшие/вышедшие дни: закрыть прежнюю ставку днём перед новой можно, если
  новая начинается в открытом месяце.
- Каждое применённое изменение — в `change_log` и `audit_log` (`sync_insert`/`sync_update`/`sync_delete`,
  прежнее и новое значение) в той же транзакции.

## Закрытые месяцы, расчёт, чтение

- `GET /periods/locks` — любой вошедший (клиенту — для отметки «месяц закрыт»);
  `POST /periods/locks` `{year, month, note?}` → 201 (`already_locked` — 409),
  `DELETE /periods/locks/<год>/<месяц>` → 204 (не закрыт — 404): закрывают бухгалтер и админ, открывает только
  админ (0.4.0; бухгалтеру — 403). Закрытие в той же транзакции сначала пересчитывает месяц (фиксируется свежий
  расчёт), открытие — пересчитывает его и следующие открытые, а перед этим сохраняет снимок в `period_snapshots`
  (остаток на начало, начислено, выплачено, остаток на конец по каждому сотруднику и месяцу — с открываемого по
  последний с данными; ответ `DELETE` — `{snapshot_id}`). `GET /periods/locks/<год>/<месяц>/unlock-preview`
  (админ) — что изменит открытие: те же шаги в транзакции, которая откатывается. `GET /periods/snapshots`,
  `GET /periods/snapshots/<id>` — снимки, `GET /periods/snapshots/<id>/changes` (0.4.1) — снимок против расчётов
  сейчас по тем же месяцам, только изменившиеся строки «было/стало» (бухгалтер и админ). Оба действия в аудите
  (`period_lock`, `period_unlock` с прежним закрытием). Закрытие ждёт незавершённые push (они читают
  `period_locks` с `FOR SHARE`).
- Расчёт — бухгалтер и админ, тем же кодом, что в приложении (`calculateMonthlySalary`, `combineBalances`,
  `payrollNeeded`). В расчёт входят сотрудники, у которых в месяце есть начисления или выплаты либо ненулевой
  входящий остаток на 1-е число:
  - `GET /payroll/calculation?year=&month=` — свежий расчёт рядом с сохранённым (`needed`, `up_to_date`), без
    записи; в списке — нужные и те, у кого остался сохранённый расчёт (его уберёт пересчёт);
  - `POST /payroll/calculate` `{year, month}` → `{saved, unchanged, removed, employees}`: записывает только
    изменившиеся расчёты (прежний uuid сохраняется), расчёт выпавшего сотрудника мягко удаляет (аудит
    `payroll_delete`), `edited_by = server`, `calculated_at` — UTC с `Z`, через `change_log` (под очередью записи)
    и аудит `payroll_save`; закрытый месяц — 409 `period_locked`;
  - `GET /payroll?year=&month=` — сохранённые расчёты (без пустых строк без выплат и остатка) и входящие остатки.
- Автопересчёт (0.4.0, этап 6.1): сохранённые расчёты открытых месяцев всегда совпадают со свежим пересчётом.
  Push, в котором принята правка табеля, выплаты, ставки, расчёта или сотрудника, в той же транзакции
  пересчитывает открытые месяцы — с самого раннего задетого (`payrollImpactFrom`; сотрудник — все месяцы) по
  последний месяц с табелем, выплатами или расчётом, по возрастанию (остаток следующего — по уже обновлённым
  предыдущим); закрытые пропускаются — их расчёт зафиксирован. То же — при открытии месяца (с него) и при запуске
  сервера (все открытые месяцы: после выкладки или восстановления из копии). Пишутся только расхождения; аудит —
  `payroll_auto_save`/`payroll_auto_delete` с пользователем и устройством правки; новая версия всегда позже
  прежней (даже если часы клиента спешили). Входящий остаток по сохранённым расчётам поэтому верен и для открытых
  месяцев. Приложение 1.5.0 расчёты не сохраняет (открытый месяц считает на лету, закрытый показывает
  зафиксированным); расчёты от старых клиентов сервер выправляет тем же приёмом.
- Чтение (права — как у pull): `GET /employees?active_on=`, `GET /timesheet?year=&month=&employee_uuid=`,
  `GET /rates?employee_uuid=`, `GET /payments?from=&to=&employee_uuid=`, `GET /settings`. Только неудалённые
  записи, поля — как в `data` синхронизации плюс `uuid`, `updated_at`, `edited_by`.

## Разовый перенос базы устройства (импорт)

1. Выгрузка на ПК (база открывается только на чтение, программа должна быть закрыта):
   ```powershell
   cd packages/local_db
   dart run tool/export_json.dart "<база_v2.db>" "<выгрузка.json>"
   ```
   Формат — `SyncExport` из `kfh_domain`: все записи всех бизнес-таблиц (включая удалённые) в формате
   синхронизации и контроль — число записей по таблицам, расчёт ЗП и входящий остаток каждого сотрудника за
   каждый месяц с табелем, выплатами или расчётом (посчитаны кодом приложения).
2. `POST /admin/import` с телом из файла (только админ, до 20 МБ, только в пустую базу — иначе 409 `not_empty`).
   Сервер проверяет всю выгрузку до записи (400 `invalid_export` со списком ошибок), пишет одной транзакцией
   под очередью записи журнала изменений (`edited_by` — как на устройстве; устройства получат записи обычным
   pull), затем до COMMIT сверяет: число записей, каждую запись поле в поле, расчёт ЗП и остатки своим кодом
   против контроля до полкопейки. Любое расхождение — откат и 422 `verification_failed` со списком. Итог — в
   аудит (`import`).

Приёмка 2026-09-27 на копии рабочей базы: 130 записей (табель 89, из них 9 удалённых), контроль 21 строка за
07–09.2026 — сошлось; независимая сверка pull с SQLite-копией — 0 расхождений.

## VPS: выкладка и бэкапы

Сервер — `https://tab.korovatech.ru` (VPS TimeWeb, `ssh kfh`, пользователь `deploy`). Файлы — `server/deploy/`.

- **Выкладка** с ПК: `.\server\deploy\publish.ps1` — архив нужных серверу файлов → VPS → `deploy.sh`
  (секреты при первом запуске → образ, прежний — `kfh-api:previous` → копия базы в
  `/opt/kfh/backups/pre-deploy` (10 последних) → `migrate` → запуск → таймер бэкапа → `https://…/health`).
- На VPS: `/opt/kfh/kfh.env` (`KFH_DOMAIN`, `KFH_BACKUP_BUCKET`, `KFH_BACKUP_AGE_RECIPIENT`), `/opt/kfh/secrets/`
  (пароли MySQL, ключ JWT, `s3.env` — ключ Object Storage). Команды compose:
  `docker compose -p kfh --env-file /opt/kfh/kfh.env -f /opt/kfh/src/server/deploy/docker-compose.prod.yml …`.
- **Бэкап вне VPS** — `backup.sh` по таймеру `kfh-backup.timer` (00:30 UTC): `mysqldump` → gzip → проверка →
  шифрование `age` → Yandex Object Storage, бакет `kfh-backups-likafarm`: `daily/` (8 дней), `weekly/` (воскресенье,
  57 дней), `monthly/` (1-е число, 366 дней). Ротацию делают правила жизненного цикла бакета, в бакете включено
  версионирование; ключ сервера (`storage.uploader` + `storage.viewer`) удалять не может. Последний успех —
  `/opt/kfh/backups/last_success`, журнал — `journalctl -u kfh-backup.service`, запуск вручную —
  `sudo systemctl start kfh-backup.service`.
- **Ключ шифрования**: открытый — в `kfh.env`, закрытый — только у владельца (`%USERPROFILE%\.kfh\backup_age.key`
  + копия вне ПК). Без него копии из бакета не расшифровать.
- **Восстановление** (проверено 2026-09-27 на реальных данных: контрольные суммы всех таблиц совпали с сервером): скачать копию (`rclone` на VPS с настройками из
  `backup.sh`, или консоль Yandex Cloud) → на ПК `age -d -i backup_age.key -o kfh.sql.gz <копия>.age` (без age —
  `docker run --rm -v <папка ключа>:/k:ro -v <папка копии>:/d alpine:3.22 sh -c "apk add age && age -d …"`) →
  `zcat kfh.sql.gz | mysql -uroot -p` в чистую MySQL 8.4 (дамп сам создаёт базу `kfh`) → `server migrate`
  (ничего не применяет) → запуск API. На VPS после восстановления — `UPDATE sync_serial SET epoch = UUID();`
  и пароль `kfh_api` из `secrets/mysql_password` (пользователи MySQL в дамп не входят).
- **Программа для телефона** (этап 4.8): `/opt/kfh/downloads` — `kfh-X.Y.Z.apk`, `index.html` (страница
  `https://…/download/`, отдаёт Caddy) и `versions.json` (читает API: `GET /client/version` без входа —
  последняя и минимальная версии по платформам, программа старее минимальной ставит синхронизацию на паузу и
  показывает «нужна новая версия»). Выкладка APK — `.\server\deploy\publish_apk.ps1 -Apk
  installer_output\kfh-X.Y.Z.apk [-Min X.Y.Z]` (сначала APK, затем список версий); только с согласия владельца.
- **Веб-версия** (этап 5): `https://…/app/` (`/` переадресует туда; API — на прежних адресах). Файлы —
  `/opt/kfh/web/releases/<время>-<версия>`, `/opt/kfh/web/app` — ссылка на текущий выпуск (Caddy: `/srv/web`,
  `Cache-Control: no-cache`, COOP/COEP — изоляция страницы для базы в OPFS). Выкладка —
  `.\server\deploy\publish_web.ps1 [-Min X.Y.Z] [-SkipBuild]`: сборка (`--base-href /app/
  --no-web-resources-cdn`) → новый выпуск → переключение ссылки → 3 последних выпуска → версия `web` в
  `versions.json` (по умолчанию минимальная = эта же: открытые вкладки старой версии просят обновить страницу);
  только с согласия владельца. Нужен Caddyfile сервера 0.3.0 (`publish.ps1`).

## Приёмка этапа 2

`tool/acceptance.dart` — сценарии критериев приёмки по HTTP: вход под тремя ролями и отказы `forbidden`, смена
пароля, выданного админом, push/pull между двумя устройствами, `duplicate` при повторе, закрытие/открытие месяца
(`period_locked`), pull с нуля и сверка расчёта ЗП сервера с сохранённым. Создаёт тестовых пользователей и
записи, поэтому работает только с `localhost`/`127.0.0.1` — на стенде, восстановленном из бэкапа (порядок — в
разделе «VPS», пароль админа на копии — `set-password`). Переменные: `KFH_ACC_URL`, `KFH_ACC_ADMIN_LOGIN`,
`KFH_ACC_ADMIN_PASSWORD`, `KFH_ACC_EXPECT_ROWS`. Пройдена 2026-09-27 на ночном бэкапе боевой базы.

## Вход и пароли

- Пароли — Argon2id (19 МиБ, 2 прохода, ~0,25 с), строка PHC; проверено по эталонной утилите `argon2`.
  Считается в отдельном isolate. Пароль 8–128 символов.
- Access — JWT HS256 на 15 минут; каждый запрос читает пользователя из базы: отключение и смена роли действуют
  сразу, смена пароля гасит выданные до неё access-токены. Refresh — 30 дней, в базе только sha256, ротация.
- Подбор: 5 неудач на логин и 30 на адрес за 15 минут → 429. Счёт в памяти процесса.
  Неизвестный логин проверяется так же долго, как известный.
- Пользователя с паролем от админа сервер заставляет сменить пароль при входе.
- Все действия со входом и пользователями — в `audit_log` в той же транзакции; хэшей паролей там нет.

## Чтение результатов MySQL

Драйвер отдаёт столбцы с флагом BINARY (строки `_bin`: uuid, хэши; `information_schema`) байтами, а JSON —
разобранным. Значения читать только через `row.text()` / `row.textOf()` (`lib/src/sql.dart`), моменты времени
в параметры — через `sqlDateTime()` (драйвер подставил бы `Z`, MySQL его не принимает).

Ошибки API — всегда `{"error": {"code": "...", "message": "..."}}`; неизвестный адрес — 404 `not_found`,
непредвиденная ошибка — 500 `internal` (подробности только в журнале). Каждый ответ несёт заголовок
`X-Request-Id`, журнал — строки JSON в stdout.

## Образ

`server/Dockerfile`, собирать из корня (`docker build -f server/Dockerfile -t kfh-api .`).
В образе только скомпилированный exe (`FROM scratch`), запуск от непривилегированного пользователя,
проверка здоровья — `/app/server healthcheck`.
