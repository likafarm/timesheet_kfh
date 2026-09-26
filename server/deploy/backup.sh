#!/usr/bin/env bash
# Ежедневный бэкап базы вне VPS: mysqldump → gzip → проверка → шифрование age
# → Yandex Object Storage. Запускает таймер systemd kfh-backup.timer
# (вручную: sudo systemctl start kfh-backup.service; журнал —
# journalctl -u kfh-backup.service).
#
# Раскладка в бакете (ротацию делают правила жизненного цикла бакета,
# у ключа сервера нет права удалять):
#   daily/   каждый день, хранится 8 дней
#   weekly/  по воскресеньям (UTC), 57 дней
#   monthly/ 1-го числа (UTC), 366 дней
#
# Копия шифруется открытым ключом age (KFH_BACKUP_AGE_RECIPIENT в kfh.env).
# Закрытый ключ есть только у владельца на ПК — на VPS копию не расшифровать.
# Расшифровка: age -d -i backup_age.key kfh-….sql.gz.age | gunzip > kfh.sql
set -euo pipefail

LOG_TAG=backup
# shellcheck source=lib.sh
. "$(dirname "$(readlink -f "$0")")/lib.sh"
load_env
[ -n "${KFH_BACKUP_BUCKET:-}" ] || fail "в $ENV_FILE не задан KFH_BACKUP_BUCKET"
[ -n "${KFH_BACKUP_AGE_RECIPIENT:-}" ] || fail "в $ENV_FILE не задан KFH_BACKUP_AGE_RECIPIENT"
[ -s "$SECRETS/s3.env" ] || fail "нет $SECRETS/s3.env (ключ Object Storage)"

# Ключ хранилища и настройки rclone — только в окружении, без файла настроек.
set -a
# shellcheck disable=SC1091
. "$SECRETS/s3.env"
set +a
export RCLONE_CONFIG_YOS_TYPE=s3 \
  RCLONE_CONFIG_YOS_PROVIDER=Other \
  RCLONE_CONFIG_YOS_ENV_AUTH=true \
  RCLONE_CONFIG_YOS_ENDPOINT=https://storage.yandexcloud.net \
  RCLONE_CONFIG_YOS_REGION=ru-central1 \
  RCLONE_S3_NO_CHECK_BUCKET=true
REMOTE=yos:$KFH_BACKUP_BUCKET

now=$(date -u +%s)
name=kfh-$(date -u -d "@$now" +%Y%m%d-%H%M%S).sql.gz.age
targets=(daily)
[ "$(date -u -d "@$now" +%u)" = 7 ] && targets+=(weekly)
[ "$(date -u -d "@$now" +%d)" = 01 ] && targets+=(monthly)

install -d -m 700 "$ROOT/backups"
work=$(mktemp -d "$ROOT/backups/tmp.XXXXXX")
trap 'rm -rf "$work"' EXIT

log "копия базы"
dump_database "$work/kfh.sql.gz"
age -r "$KFH_BACKUP_AGE_RECIPIENT" -o "$work/$name" "$work/kfh.sql.gz"
rm -f "$work/kfh.sql.gz"
size=$(stat -c %s "$work/$name")

for t in "${targets[@]}"; do
  log "выгрузка $t/$name ($size байт)"
  # copyto сверяет MD5 с ETag; размер проверяем ещё раз отдельно.
  rclone -q copyto "$work/$name" "$REMOTE/$t/$name"
  remote_size=$(rclone -q lsjson "$REMOTE/$t/$name" | grep -o '"Size":[0-9]*' | cut -d: -f2)
  [ "$remote_size" = "$size" ] || fail "$t/$name: в хранилище $remote_size байт вместо $size"
done

echo "$(date -u +%FT%TZ) ${targets[*]} $name $size" > "$ROOT/backups/last_success"
log "готово: $name → ${targets[*]}"
