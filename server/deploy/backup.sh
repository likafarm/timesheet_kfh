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
# Вместе с дампом делается выгрузка для модуля «Резервные копии» программы
# (этап «Дальнейшие работы», шаг 3): снимок всех записей в JSON
# (`api export`), сжатый и зашифрованный тем же ключом —
# kfh-….json.gz.age. Она кладётся в бакет рядом с дампом и в
# /opt/kfh/snapshots: оттуда её отдаёт API администратору (GET
# /admin/backups), расшифровывает программа на ПК владельца. На диске VPS
# выгрузки хранятся по тем же срокам, что и в бакете.
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

# Выгрузка для программы — после основной копии: её сбой дамп не отменяет.
snap=kfh-$(date -u -d "@$now" +%Y%m%d-%H%M%S).json.gz.age
log "выгрузка для программы"
if ! "${COMPOSE[@]}" run --rm -T --no-deps api export </dev/null | gzip > "$work/snapshot.json.gz"; then
  fail "выгрузка для программы не удалась (сервер не знает команду export?)"
fi
gzip -t "$work/snapshot.json.gz" || fail "выгрузка для программы повреждена"
# grep -c читает поток до конца: с -q zcat получил бы SIGPIPE (pipefail).
zcat "$work/snapshot.json.gz" | grep -c '^{"format":"kfh-snapshot"' >/dev/null \
  || fail "выгрузка для программы — не снимок данных"
age -r "$KFH_BACKUP_AGE_RECIPIENT" -o "$work/$snap" "$work/snapshot.json.gz"
rm -f "$work/snapshot.json.gz"
snap_size=$(stat -c %s "$work/$snap")
for t in "${targets[@]}"; do
  rclone -q copyto "$work/$snap" "$REMOTE/$t/$snap"
  remote_size=$(rclone -q lsjson "$REMOTE/$t/$snap" | grep -o '"Size":[0-9]*' | cut -d: -f2)
  [ "$remote_size" = "$snap_size" ] || fail "$t/$snap: в хранилище $remote_size байт вместо $snap_size"
done
install -d -m 755 "$SNAPSHOTS"
install -m 644 "$work/$snap" "$SNAPSHOTS/$snap"

# Сроки хранения на диске — как в бакете: 8 дней; воскресные — 57 дней;
# за 1-е число — 366 дней.
for f in "$SNAPSHOTS"/kfh-*.json.gz.age; do
  [ -e "$f" ] || continue
  day=$(basename "$f" | sed -n 's/^kfh-\([0-9]\{8\}\)-[0-9]\{6\}\.json\.gz\.age$/\1/p')
  [ -n "$day" ] || continue
  age_days=$(( (now - $(date -u -d "$day" +%s)) / 86400 ))
  keep=8
  [ "$(date -u -d "$day" +%u)" = 7 ] && keep=57
  [ "${day:6:2}" = 01 ] && keep=366
  [ "$age_days" -gt "$keep" ] && rm -f "$f"
done
log "выгрузка для программы: $snap ($snap_size байт)"
