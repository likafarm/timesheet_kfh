# CLAUDE.md

Учёт рабочего времени и расчёт ЗП для небольшого КФХ. Flutter, пока только Windows, SQLite через `sqflite_common_ffi`, состояние — `provider`.
Владелец проекта один, он же пользователь. Общение, комментарии в коде и коммиты — **на русском**.

## Статус

- Этап 0 (гигиена, тесты, вынос расчёта ЗП) — **завершён** 2026-09-25, влит в `main`.
- Перенос базы в AppData — **завершён** 2026-09-25: рабочая база в `%LOCALAPPDATA%\KFH Time Tracking`, старые файлы в папке программы удалены владельцем.
- Этап 1 (drift, UUID, схема v2) — **идёт** в ветке `feature/stage-1-drift-v2`. Шаги 1.1 (пакет `domain`), 1.2 (пакет `local_db`, схема v2) 1.3 (конвертер v8 → v2) и 1.4 (строковые id моделей, репозитории) сделаны. Следующий — 1.5 (переключение приложения на drift).
- Решения по этапу 1: удаление сотрудника убрать (только увольнение + мягкое удаление без каскада); `pending_changes` создать, но наполнять с этапа 3; `edited_by` = id устройства; база v2 — новый файл `kfx_time_tracking_v2.db`, старый не трогается.

## Команды

```bash
flutter analyze                     # должно быть 0 замечаний
flutter test                        # тесты приложения (test/), должны быть зелёными
dart test                           # в packages/domain и packages/local_db: тесты пакетов
dart run build_runner build         # в packages/local_db: после правки таблиц/DAO (.g.dart в git)
dart run drift_dev schema dump lib/src/database.dart drift_schemas/  # снимок схемы при смене версии
flutter build windows --release     # ~2 мин
.\build_installer.ps1               # установщик Inno Setup → installer_output\
```

Inno Setup стоит в `C:\Program Files (x86)\Inno Setup 6\`, но не в PATH — тогда скрипт собирает только ZIP. Установщик вручную: `& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "/DAppVer=<версия>" installer.iss`.

`flutter analyze` и `flutter build` выводят много лишнего — смотреть только хвост вывода (`| tail`).

## Архитектура

- Dart workspace: корневой `pubspec.yaml` перечисляет `packages/*` в `workspace:`, у пакетов `resolution: workspace`, `pubspec.lock` один — в корне.
- `packages/domain` (пакет `kfh_domain`, импорт `package:kfh_domain/kfh_domain.dart`) — чистый Dart без Flutter и БД: модели, расчёт ЗП (`calculateMonthlySalary`, `findRateAtDate`, `combineBalances`), `date_utils`. Новую бизнес-логику класть сюда и покрывать тестами (`dart test`). Там же интерфейсы репозиториев (`repositories.dart`, `DuplicateEntryException`) и `PayrollService` (расчёт месяца и входящие остатки поверх репозиториев). Id моделей — `String` (uuid). `toMap`/`fromMap` в моделях и перевод id в INTEGER в `DatabaseService` — временно, до перехода на drift (шаг 1.5).
- `packages/local_db` (пакет `kfh_local_db`) — чистый Dart: схема v2 на drift (`LocalDatabase`, таблицы в `lib/src/tables/tables.dart`) и DAO; `DriftRepositories` — реализация репозиториев домена. Ключ `uuid` (v7), поля `legacy_id`, `updated_at` (UTC, текстом ISO), `deleted`, `edited_by` (id устройства из `sync_state`), `remote_updated_at`. DAO сами ставят `updated_at`/`edited_by`, удаление мягкое, чтения фильтруют `deleted = 0`. Внешние ключи отложенные, уникальные индексы частичные (`WHERE deleted = 0`). Версия drift-схемы — 1 (новый файл, не миграция v8). drift и drift_dev закреплены на 2.34.0: новее не сходится с Flutter 3.44 (analyzer).
- Конвертер `convertV8ToV2` (`packages/local_db/lib/src/migration/v8_converter.dart`): принимает только базу `user_version = 8`, старый файл открывает только на чтение, пишет в `<цель>.tmp`, сверяет все поля всех строк через `legacy_id` и пересчёт ЗП за каждый месяц, делает `integrity_check`/`foreign_key_check`, затем переименовывает файл. Если цель уже есть — отказ. Прогон на копии: `dart run tool/convert_v8.dart <v8.db> <v2.db>` в `packages/local_db`.
- `lib/services/database_service.dart` — синглтон, схема БД (версия 8, миграции в `_onUpgrade`), CRUD. Загружает данные и передаёт их в `domain`. Открытие базы однократное (`_opening`), параллельные запросы ждут его.
- `lib/services/db_location.dart` — путь к базе `%LOCALAPPDATA%\KFH Time Tracking\kfx_time_tracking.db` (debug-сборка — `KFH Time Tracking (debug)`) и одноразовый перенос старой базы из `.dart_tool\sqflite_common_ffi\databases` (папка exe, затем рабочая папка): копия → `integrity_check` → переименование, оригинал не трогается, при ошибке открывается старая база. Журнал — `db_location.log` рядом с базой.
- `lib/providers/app_provider.dart` — единый `ChangeNotifier`, через него ходит UI.
- `lib/services/print_service.dart` — печать PDF (шрифты Roboto из `assets/fonts/` нужны для кириллицы).
- `lib/services/backup_service.dart` — копии в `Документы\backups`, авто-копия при запуске, хранится 5 ежедневных.
- Тема — только `lib/theme/app_theme.dart`. Версия — только `pubspec.yaml` (её читают exe, «О программе» через `package_info_plus` и установщик).

## Доменные правила

- Табель: `dayType` = `work` | `sick` | `vacation` | `dayoff`; для `work` значение `days` равно 1 или 0.5, `workPlace` = `base` | `field`.
- Ставка действует на дату, если `start_date <= дата <= end_date` (`end_date = null` — бессрочно). Новая ставка закрывает предыдущую датой «начало − 1 день».
- Рабочий день без ставки не оплачивается, а учитывается в `skippedWorkDays`.
- Остаток = начислено за прошлые месяцы − выплачено до 1-го числа месяца.
- Даты в БД хранятся строками ISO `гггг-мм-дд` (`packages/domain/lib/src/utils/date_utils.dart`). Старые записи со временем читаются через `parseDateIso`.
- `calculateMonthlySalaryDetailed` возвращает `Map` с прежними ключами — вызывающий код в `AppProvider` зависит от них.

## Правила работы

- Развитие идёт по этапам из `DEVELOPMENT_PLAN.md`. **Каждый этап — только после явного согласия владельца**, в ветке `feature/stage-N-...`.
- Требования к интерфейсу — `UI_REQUIREMENTS.md` (читать при работе над экранами, а не целиком каждый раз).
- Любое изменение схемы БД или миграция — только после свежей резервной копии и на копии реальной базы. Боевую базу не трогать.
- Боевая база — `%LOCALAPPDATA%\KFH Time Tracking\kfx_time_tracking.db`. `flutter run` (debug) работает с отдельной базой в `KFH Time Tracking (debug)`.
- Claude desktop — MSIX-приложение: записи его инструментов в `%LOCALAPPDATA%` виртуализируются в `%LOCALAPPDATA%\Packages\Claude_*\LocalCache\`, другим программам они не видны, а при чтении виртуальная копия заслоняет настоящую. К настоящей AppData обращаться через `\\localhost\C$\Users\<пользователь>\AppData\Local\...`. `Документы` не виртуализируются.
- Перед коммитом: `flutter analyze`, `flutter test` и `dart test` в `packages/domain` и `packages/local_db` зелёные.
- `build_installer.ps1` держать в ASCII (транслит): Windows PowerShell 5.1 читает UTF-8 без BOM как ANSI.
- Рабочие файлы в LF, Git конвертирует их в CRLF — это нормально.

## Известные проблемы (ждут решения владельца)

- Рабочий день без `workPlace` оплачивается по ставке поля, но не попадает в счётчики дней. Поведение сохранено сознательно, пока нет решения.
