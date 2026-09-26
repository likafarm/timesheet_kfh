# CLAUDE.md

Учёт рабочего времени и расчёт ЗП для небольшого КФХ. Flutter, пока только Windows, SQLite через drift (пакет `packages/local_db`), состояние — `provider`.
Владелец проекта один, он же пользователь. Общение, комментарии в коде и коммиты — **на русском**.

## Статус

- Этап 0 (гигиена, тесты, вынос расчёта ЗП) — **завершён** 2026-09-25, влит в `main`.
- Перенос базы в AppData — **завершён** 2026-09-25: рабочая база в `%LOCALAPPDATA%\KFH Time Tracking`, старые файлы в папке программы удалены владельцем.
- Этап 1 (домен-пакет, drift, UUID, схема v2) — **завершён** 2026-09-26, влит в `main`, версия 1.1.0. Боевая база переносится в `kfx_time_tracking_v2.db` при первом запуске 1.1.0 (владелец установил и проверил).
- Этап 2 (сервер: API + MySQL на VPS) — **идёт** с 2026-09-26 в ветке `feature/stage-2-server`. Шаги 2.1–2.6 — локально (Docker Desktop), 2.7–2.8 — на VPS (от владельца нужны доступ к VPS, домен и решение по хранилищу бэкапов).
- Решения по этапу 2: сервер на `shelf` (не Dart Frog); ставку, начинающуюся в закрытом месяце, сервер отклоняет; роли — оператор: табель и просмотр сотрудников; бухгалтер: всё, кроме пользователей; админ: всё.
- Решения по этапу 1: удаление сотрудника убрать (только увольнение + мягкое удаление без каскада); `pending_changes` создать, но наполнять с этапа 3; `edited_by` = id устройства; база v2 — новый файл `kfx_time_tracking_v2.db`, старый не трогается.

## Команды

```bash
flutter analyze                     # должно быть 0 замечаний
flutter test                        # тесты приложения (test/), должны быть зелёными
# приёмка на КОПИИ реальной базы: $env:KFH_ACCEPTANCE_DB="<копия.db>"; flutter test test/acceptance/real_db_test.dart
dart test                           # в packages/domain, packages/local_db и server: тесты пакетов
docker compose -f server/docker-compose.dev.yml up -d --build   # стенд сервера: MySQL + API на localhost:8080
# тесты сервера на MySQL стенда: cd server; $env:KFH_TEST_MYSQL="1"; dart test -t mysql
dart run build_runner build         # в packages/local_db: после правки таблиц/DAO (.g.dart в git)
dart run drift_dev schema dump lib/src/database.dart drift_schemas/  # снимок схемы при смене версии
flutter build windows --release     # ~2 мин
.\build_installer.ps1               # установщик Inno Setup → installer_output\
```

Inno Setup стоит в `C:\Program Files (x86)\Inno Setup 6\`, но не в PATH — тогда скрипт собирает только ZIP. Установщик вручную: `& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "/DAppVer=<версия>" installer.iss`.

`flutter analyze` и `flutter build` выводят много лишнего — смотреть только хвост вывода (`| tail`).

## Архитектура

- Dart workspace: корневой `pubspec.yaml` перечисляет `packages/*` в `workspace:`, у пакетов `resolution: workspace`, `pubspec.lock` один — в корне.
- `packages/domain` (пакет `kfh_domain`, импорт `package:kfh_domain/kfh_domain.dart`) — чистый Dart без Flutter и БД: модели, расчёт ЗП (`calculateMonthlySalary`, `findRateAtDate`, `combineBalances`), `date_utils`. Новую бизнес-логику класть сюда и покрывать тестами (`dart test`). Там же интерфейсы репозиториев (`repositories.dart`, `DuplicateEntryException`) и `PayrollService` (расчёт месяца и входящие остатки поверх репозиториев). Id моделей — `String` (uuid). У моделей нет `toMap`/`fromMap`: преобразование в строки базы — в `DriftRepositories`. Снять увольнение — `copyWith(clearDismissalDate: true)` (`dismissalDate: null` в copyWith значит «не менять»).
- `packages/local_db` (пакет `kfh_local_db`) — чистый Dart: схема v2 на drift (`LocalDatabase`, таблицы в `lib/src/tables/tables.dart`) и DAO; `DriftRepositories` — реализация репозиториев домена. Ключ `uuid` (v7), поля `legacy_id`, `updated_at` (UTC, текстом ISO), `deleted`, `edited_by` (id устройства из `sync_state`), `remote_updated_at`. DAO сами ставят `updated_at`/`edited_by`, удаление мягкое, чтения фильтруют `deleted = 0`. Внешние ключи отложенные, уникальные индексы частичные (`WHERE deleted = 0`). Версия drift-схемы — 1 (новый файл, не миграция v8). drift и drift_dev закреплены на 2.34.0: новее не сходится с Flutter 3.44 (analyzer).
- `packages/local_db/lib/src/schema_info.dart` — списки бизнес-таблиц, поля-даты, служебные поля, уникальные ключи. `raw_tables.dart` (`RawTables`) — просмотр и правка таблиц «как есть»: правка ставит `updated_at`/`edited_by`, служебные поля не правятся, удаление мягкое и обратимое, служебные таблицы — только чтение. `backup_restore.dart` — `detectBackupFormat` (v8/v2), `prepareFullRestore` (файл v2 из копии любого формата, v8 — через конвертер; id устройства сохраняется), `BackupRestorer` (таблицы и строки — только из копий v2, по uuid, с новым `updated_at`; занятый день табеля/месяц расчёта освобождается мягким удалением).
- Конвертер `convertV8ToV2` (`packages/local_db/lib/src/migration/v8_converter.dart`): принимает только базу `user_version = 8`, старый файл открывает только на чтение, пишет в `<цель>.tmp`, сверяет все поля всех строк через `legacy_id` и пересчёт ЗП за каждый месяц, делает `integrity_check`/`foreign_key_check`, затем переименовывает файл. Если цель уже есть — отказ. Прогон на копии: `dart run tool/convert_v8.dart <v8.db> <v2.db>` в `packages/local_db`.
- `server/` (пакет `kfh_server`, член workspace) — API на `shelf` + MySQL (`mysql_client_plus`, TLS, utf8mb4). Пул соединений свой (`server/lib/src/pool.dart`): пул пакета после ошибки возвращает закрытое соединение (сервер не оживает после перезапуска MySQL) и теряет соединения при исключении — его `MySQLConnectionPool` не использовать. Настройки только из переменных окружения (`ServerConfig`), журнал — JSON-строки в stdout, ошибки API — `{"error":{"code","message"}}` (`ApiException`), у ответа `X-Request-Id`. Версия — `server/pubspec.yaml` и `lib/src/version.dart` (сверяет тест). Образ — `server/Dockerfile` из корня репозитория: внутри собирается свой workspace (domain + server), т.к. корневой pubspec требует Flutter. Подробности — `server/README.md`.
- `lib/services/app_database.dart` — `openAppDatabase` в `main.dart` до `runApp`: если `kfx_time_tracking_v2.db` нет, находит старую базу v8 (`db_location.dart`), делает её копию `backup_v8_<дата-время>.db` и переносит конвертером в `Isolate.run`. Без копии перенос не начинается. Если перенос не прошёл — `StartupErrorApp` с причиной, ни одна база не открыта, старая не тронута, при следующем запуске повтор. `AppDatabase` = `LocalDatabase` + `DriftRepositories` + путь. Полное восстановление (`AppProvider.restoreFullBackup`): копия текущей базы `backup_before_restore_…` → файл `.restore` в `Isolate.run` → закрыть базу → `replaceDatabaseFile` (старый файл через `.old`) → переоткрыть. Любое восстановление начинается с копии текущей базы.
- `lib/services/db_location.dart` — пути: старая база v8 `%LOCALAPPDATA%\KFH Time Tracking\kfx_time_tracking.db`, новая `kfx_time_tracking_v2.db` там же (debug-сборка — `KFH Time Tracking (debug)`). Одноразовый переезд v8 из `.dart_tool\sqflite_common_ffi\databases` (папка exe, затем рабочая папка — там лежит старая dev-база, `flutter run` переносит её). Журнал — `db_location.log` рядом с базой.
- `lib/providers/app_provider.dart` — единый `ChangeNotifier` над `AppDatabase`, через него ходит UI; к базе — только через репозитории и `PayrollService`. Удаления сотрудника нет (только увольнение).
- `lib/services/print_service.dart` — печать PDF (шрифты Roboto из `assets/fonts/` нужны для кириллицы).
- `lib/services/backup_service.dart` — копии в `Документы\backups` (debug-сборка — `Документы\backups (debug)`), снимок открытой базы через `VACUUM INTO`, авто-копия при запуске, хранится 5 ежедневных. Копии читаются через `sqlite3` только на чтение. В папке могут лежать копии обоих форматов (v8 — до 26.09.2026).
- `lib/utils/cell_format.dart` — показ значений в экранах просмотра базы и копий (день ISO → `дд.мм.гггг`, момент UTC → местное время) и разбор ввода при правке. Экран просмотра базы — только в debug-сборке (`kDebugMode` в настройках).
- Тема — только `lib/theme/app_theme.dart`. Версия — только `pubspec.yaml` (её читают exe, «О программе» через `package_info_plus` и установщик).

## Доменные правила

- Табель: `dayType` = `work` | `sick` | `vacation` | `dayoff`; для `work` значение `days` равно 1 или 0.5, `workPlace` = `base` | `field`.
- Ставка действует на дату, если `start_date <= дата <= end_date` (`end_date = null` — бессрочно). Новая ставка закрывает предыдущую датой «начало − 1 день».
- Рабочий день без ставки не оплачивается, а учитывается в `skippedWorkDays`.
- Остаток = начислено за прошлые месяцы − выплачено до 1-го числа месяца.
- Даты в БД хранятся строками ISO `гггг-мм-дд` (`packages/domain/lib/src/utils/date_utils.dart`). Старые записи со временем читаются через `parseDateIso`.
- `AppProvider.calculateMonthlySalary`/`calculateSingleEmployeePayroll` возвращают `PayrollCalculation.toMap()` с прежними ключами — экраны зависят от них.

## Правила работы

- Развитие идёт по этапам из `DEVELOPMENT_PLAN.md`. **Каждый этап — только после явного согласия владельца**, в ветке `feature/stage-N-...`.
- Требования к интерфейсу — `UI_REQUIREMENTS.md` (читать при работе над экранами, а не целиком каждый раз).
- Любое изменение схемы БД или миграция — только после свежей резервной копии и на копии реальной базы. Боевую базу не трогать.
- Боевая база — `%LOCALAPPDATA%\KFH Time Tracking\kfx_time_tracking.db` (v8), после первого запуска версии с drift — `kfx_time_tracking_v2.db` рядом. `flutter run` (debug) работает с отдельной базой в `KFH Time Tracking (debug)` и отдельной папкой копий. Релизный exe из инструментов Claude не запускать: он найдёт настоящую базу.
- Claude desktop — MSIX-приложение: записи его инструментов в `%LOCALAPPDATA%` виртуализируются в `%LOCALAPPDATA%\Packages\Claude_*\LocalCache\`, другим программам они не видны, а при чтении виртуальная копия заслоняет настоящую. К настоящей AppData обращаться через `\\localhost\C$\Users\<пользователь>\AppData\Local\...`. `Документы` не виртуализируются.
- Перед коммитом: `flutter analyze`, `flutter test` и `dart test` в `packages/domain`, `packages/local_db` и `server` зелёные (для сервера — ещё `dart analyze` в `server/`).
- `build_installer.ps1` держать в ASCII (транслит): Windows PowerShell 5.1 читает UTF-8 без BOM как ANSI.
- Рабочие файлы в LF, Git конвертирует их в CRLF — это нормально.

## Известные проблемы (ждут решения владельца)

- Рабочий день без `workPlace` оплачивается по ставке поля, но не попадает в счётчики дней. Поведение сохранено сознательно, пока нет решения.
