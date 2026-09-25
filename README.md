# Учёт рабочего времени КФХ

Настольное приложение (Windows) для учёта рабочих дней и расчёта зарплаты
в небольшом крестьянском (фермерском) хозяйстве.

Возможности: сотрудники и история ставок (база / поле), табель по дням
(рабочий день, 0,5 дня, больничный, отпуск, выходной), расчёт зарплаты за месяц,
выплаты и остатки, отчёты, печать табеля в PDF, резервные копии.

Технологии: Flutter (Windows), SQLite (`sqflite_common_ffi`), `provider`, `pdf`/`printing`.

## Структура

```
lib/
  domain/     чистая бизнес-логика без БД и UI (расчёт ЗП) — покрыта тестами
  models/     модели данных
  services/   БД, резервные копии, печать
  providers/  состояние приложения (AppProvider)
  screens/    экраны
  widgets/    диалоги и общие виджеты
  utils/      даты, строки, константы
test/         модульные тесты
```

Планы развития — в [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md),
требования к интерфейсу — в [UI_REQUIREMENTS.md](UI_REQUIREMENTS.md).

## Разработка

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

## Сборка и установщик

1. Поднять версию в `pubspec.yaml` (`version: X.Y.Z+N`) — это единственное место,
   где она задаётся: её подхватывают exe-файл, окно «О программе» и установщик.
2. Собрать релиз:
   ```bash
   flutter build windows --release
   ```
3. Собрать установщик (нужен [Inno Setup](https://jrsoftware.org/isinfo.php), `iscc` в PATH):
   ```powershell
   .\build_installer.ps1
   ```
   Результат — `installer_output\KFH_TimeTracking_Setup_X.Y.Z.exe`.
   Без Inno Setup скрипт соберёт переносной ZIP.

## Где лежат данные

- **База данных:** `.dart_tool\sqflite_common_ffi\databases\kfx_time_tracking.db`
  относительно рабочей папки приложения. Для установленной версии это
  `%LOCALAPPDATA%\Programs\KFH Time Tracking\.dart_tool\...`,
  при запуске из исходников — папка проекта.
- **Резервные копии:** `Документы\backups` текущего пользователя
  (`BackupService`); автоматическая копия при запуске, хранятся последние 5 ежедневных.
