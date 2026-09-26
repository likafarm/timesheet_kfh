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

Без обязательной переменной сервер не стартует (код выхода 78, причина — в журнале).

## Локальный стенд (Docker Desktop)

```powershell
docker compose -f server/docker-compose.dev.yml up -d --build   # из корня репозитория
curl.exe http://localhost:8080/health
docker compose -f server/docker-compose.dev.yml logs api
docker compose -f server/docker-compose.dev.yml down            # данные MySQL сохраняются (down -v — удалить)
```

MySQL стенда доступна с этого ПК на `127.0.0.1:3307` (`kfh_api` / `dev-api`, root / `dev-root`).
Пароли — только для разработки.

## Тесты

```powershell
cd server
dart test                                   # без MySQL (тесты с тегом mysql пропускаются)
$env:KFH_TEST_MYSQL="1"; dart test -t mysql # на стенде; хост/порт/учётка — KFH_TEST_DB_*
```

## Эндпоинты

- `GET /health` — 200 `{"status":"ok","version":"…","db":"ok"}`; если MySQL не отвечает за 3 с — 503.

Ошибки API — всегда `{"error": {"code": "...", "message": "..."}}`; неизвестный адрес — 404 `not_found`,
непредвиденная ошибка — 500 `internal` (подробности только в журнале). Каждый ответ несёт заголовок
`X-Request-Id`, журнал — строки JSON в stdout.

## Образ

`server/Dockerfile`, собирать из корня (`docker build -f server/Dockerfile -t kfh-api .`).
В образе только скомпилированный exe (`FROM scratch`), запуск от непривилегированного пользователя,
проверка здоровья — `/app/server healthcheck`.
