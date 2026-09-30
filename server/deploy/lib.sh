# Общее для deploy.sh и backup.sh (подключается через «.», сам не запускается).
#
# Перед подключением задать LOG_TAG (метка в журнале). Команды docker compose
# запускаются с закрытым stdin: иначе они съедают остаток скрипта, если тот
# читается из stdin.

ROOT=/opt/kfh
SRC=$ROOT/src
ENV_FILE=$ROOT/kfh.env
SECRETS=$ROOT/secrets
# Зашифрованные выгрузки для модуля копий программы: пишет backup.sh, читает API.
SNAPSHOTS=$ROOT/snapshots
COMPOSE=(docker compose -p kfh --env-file "$ENV_FILE" -f "$SRC/server/deploy/docker-compose.prod.yml")

log() { echo "[${LOG_TAG:-kfh} $(date -u +%FT%TZ)] $*"; }
fail() { echo "[${LOG_TAG:-kfh}] ОШИБКА: $*" >&2; exit 1; }

load_env() {
  [ -f "$ENV_FILE" ] || fail "нет $ENV_FILE (строка KFH_DOMAIN=<домен>)"
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  [ -n "${KFH_DOMAIN:-}" ] || fail "в $ENV_FILE не задан KFH_DOMAIN"
}

# Команда клиента MySQL от root внутри контейнера; пароль — через MYSQL_PWD,
# не в командной строке.
mysql_root() {
  "${COMPOSE[@]}" exec -T mysql sh -c 'MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" exec "$0" -uroot "$@"' "$@" </dev/null
}

# Число таблиц в базе kfh (0 — база пустая).
kfh_table_count() {
  mysql_root mysql -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'kfh'"
}

# Полная копия базы kfh в сжатый файл $1. Пишет во временный файл, проверяет
# целостность gzip и отметку mysqldump о завершении, затем переименовывает.
dump_database() {
  local out=$1
  (umask 077
   mysql_root mysqldump --single-transaction --routines --triggers --events \
     --set-gtid-purged=OFF --hex-blob --no-tablespaces \
     --default-character-set=utf8mb4 --databases kfh | gzip > "$out.tmp")
  gzip -t "$out.tmp" || fail "копия базы повреждена"
  zcat "$out.tmp" | tail -n 1 | grep -q 'Dump completed' || fail "копия базы неполная"
  mv "$out.tmp" "$out"
}
