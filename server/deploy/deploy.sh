#!/usr/bin/env bash
# Выкладка сервера на VPS: исходники → образ → копия базы → миграции → запуск → проверка.
#
# Запускается на VPS от пользователя deploy; исходники приходят архивом
# (с ПК — server/deploy/publish.ps1):
#
#   tar -xOf /tmp/kfh-src.tar server/deploy/deploy.sh > /tmp/kfh-deploy.sh
#   bash /tmp/kfh-deploy.sh /tmp/kfh-src.tar <ревизия>
#
# Не через «| bash -s»: команды docker compose читают stdin и съели бы
# остаток скрипта. По той же причине у них stdin закрыт (</dev/null).
#
# Раскладка на VPS:
#   /opt/kfh/kfh.env      KFH_DOMAIN=… (создаётся один раз вручную)
#   /opt/kfh/secrets/     пароли MySQL и ключ JWT (создаются здесь при первом запуске)
#   /opt/kfh/src/         текущие исходники (src.prev — предыдущие)
#   /opt/kfh/backups/pre-deploy/  копия базы перед каждой выкладкой (последние 10)
#
# Откат кода: образ kfh-api:previous. Откат схемы — только восстановлением
# копии из backups/pre-deploy (DDL в MySQL не откатывается).
set -euo pipefail

ARCHIVE=${1:?укажите архив исходников}
REV=${2:-unknown}
ROOT=/opt/kfh
SRC=$ROOT/src
ENV_FILE=$ROOT/kfh.env
SECRETS=$ROOT/secrets
BACKUPS=$ROOT/backups/pre-deploy
COMPOSE=(docker compose -p kfh --env-file "$ENV_FILE" -f "$SRC/server/deploy/docker-compose.prod.yml")

log() { echo "[deploy $(date -u +%FT%TZ)] $*"; }
fail() { echo "[deploy] ОШИБКА: $*" >&2; exit 1; }

[ -f "$ENV_FILE" ] || fail "нет $ENV_FILE (строка KFH_DOMAIN=<домен>)"
# shellcheck disable=SC1090
. "$ENV_FILE"
[ -n "${KFH_DOMAIN:-}" ] || fail "в $ENV_FILE не задан KFH_DOMAIN"

# 1. Секреты — только при первом запуске. Если база уже есть, а пароля нет,
#    новый пароль к ней не подойдёт: останавливаемся.
install -d -m 700 "$SECRETS"
install -d -m 700 "$ROOT/backups" "$BACKUPS"
db_volume_exists=false
docker volume inspect kfh_mysql-data >/dev/null 2>&1 && db_volume_exists=true
for name in mysql_root_password mysql_password jwt_secret; do
  file=$SECRETS/$name
  if [ ! -s "$file" ]; then
    if $db_volume_exists && [ "$name" != jwt_secret ]; then
      fail "нет $file, а база MySQL уже создана — восстановите файл из копии"
    fi
    log "создаю секрет $name"
    # 48 случайных байт → 64 символа без / + =
    (umask 0333; openssl rand -base64 48 | tr -d '\n/+=' > "$file")
  fi
  chmod 444 "$file" # папка 700: снаружи не прочитать, а контейнеру (не root) — можно
done

# 2. Исходники: src.new → src, прежние — в src.prev.
log "исходники ревизии $REV"
rm -rf "$ROOT/src.new"
mkdir -p "$ROOT/src.new"
tar -xf "$ARCHIVE" -C "$ROOT/src.new"
echo "$REV" > "$ROOT/src.new/REVISION"
rm -rf "$ROOT/src.prev"
[ -d "$SRC" ] && mv "$SRC" "$ROOT/src.prev"
mv "$ROOT/src.new" "$SRC"

# 3. Образ. Прежний остаётся как kfh-api:previous.
if docker image inspect kfh-api:current >/dev/null 2>&1; then
  docker tag kfh-api:current kfh-api:previous
fi
log "сборка образа"
"${COMPOSE[@]}" build api

# 4. MySQL.
log "MySQL"
"${COMPOSE[@]}" up -d --wait mysql

mysql_root() {
  # пароль — через MYSQL_PWD, не в командной строке
  "${COMPOSE[@]}" exec -T mysql sh -c 'MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" exec "$0" -uroot "$@"' "$@" </dev/null
}

# 5. Копия базы перед миграциями (если в ней уже есть таблицы).
tables=$(mysql_root mysql -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'kfh'")
if [ "$tables" -gt 0 ]; then
  dump=$BACKUPS/kfh-$(date -u +%Y%m%d-%H%M%S)-$REV.sql.gz
  log "копия базы → $dump"
  (umask 077
   mysql_root mysqldump --single-transaction --routines --triggers --events \
     --set-gtid-purged=OFF --hex-blob --no-tablespaces \
     --default-character-set=utf8mb4 --databases kfh | gzip > "$dump.tmp")
  gzip -t "$dump.tmp" || fail "копия базы повреждена"
  zcat "$dump.tmp" | tail -n 1 | grep -q 'Dump completed' || fail "копия базы неполная"
  mv "$dump.tmp" "$dump"
  ls -1t "$BACKUPS"/kfh-*.sql.gz | tail -n +11 | xargs -r rm -f
else
  log "база пустая — копия не нужна"
fi

# 6. Миграции.
log "миграции"
"${COMPOSE[@]}" run --rm --no-deps api migrate </dev/null

# 7. Запуск.
log "запуск API и Caddy"
"${COMPOSE[@]}" up -d --wait --remove-orphans api caddy

# 8. Проверка снаружи, через HTTPS (первый раз Caddy получает сертификат).
log "проверка https://$KFH_DOMAIN/health"
for _ in $(seq 1 40); do
  if body=$(curl -fsS --max-time 5 "https://$KFH_DOMAIN/health" 2>/dev/null); then
    log "готово: $body"
    docker image prune -f >/dev/null
    rm -f "$ARCHIVE"
    exit 0
  fi
  sleep 3
done
"${COMPOSE[@]}" ps
"${COMPOSE[@]}" logs --tail 40 api caddy
fail "https://$KFH_DOMAIN/health не отвечает"
