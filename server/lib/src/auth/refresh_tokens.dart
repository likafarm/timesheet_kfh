import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../sql.dart';
import 'users.dart';

final _random = Random.secure();

/// Новый refresh-токен: 32 случайных байта, base64url.
String newRefreshToken() => base64Url
    .encode(List.generate(32, (_) => _random.nextInt(256)))
    .replaceAll('=', '');

/// В базе лежит только sha256 токена: утечка таблицы не даёт войти.
String hashRefreshToken(String token) =>
    sha256.convert(utf8.encode(token)).toString();

class StoredRefreshToken {
  final String userUuid;
  final String family;
  final String? deviceId;
  final DateTime expiresAt;
  final DateTime? revokedAt;

  StoredRefreshToken(this.userUuid, this.family, this.deviceId, this.expiresAt,
      this.revokedAt);
}

/// Запросы к таблице `refresh_tokens`.
class RefreshTokenStore {
  const RefreshTokenStore();

  Future<void> insert(
    SqlExecutor sql, {
    required String token,
    required String userUuid,
    required String family,
    required String? deviceId,
    required DateTime now,
    required DateTime expiresAt,
  }) =>
      sql(
          'INSERT INTO refresh_tokens (token_hash, user_uuid, family, '
          'device_id, created_at, expires_at) VALUES (:h, :u, :f, :d, :now, '
          ':exp)',
          {
            'h': hashRefreshToken(token),
            'u': userUuid,
            'f': family,
            'd': deviceId,
            'now': sqlDateTime(now),
            'exp': sqlDateTime(expiresAt),
          });

  /// Строка токена с блокировкой до конца транзакции: один и тот же
  /// токен нельзя обменять дважды параллельными запросами.
  Future<StoredRefreshToken?> findForUpdate(
      SqlExecutor sql, String token) async {
    final r = await sql(
        'SELECT user_uuid, family, device_id, expires_at, revoked_at '
        'FROM refresh_tokens WHERE token_hash = :h FOR UPDATE',
        {'h': hashRefreshToken(token)});
    if (r.rows.isEmpty) return null;
    final row = r.rows.first;
    return StoredRefreshToken(
      row.textOf('user_uuid'),
      row.textOf('family'),
      row.text('device_id'),
      parseSqlDateTime(row.textOf('expires_at')),
      parseSqlDateTimeOrNull(row.text('revoked_at')),
    );
  }

  Future<void> revoke(SqlExecutor sql, String token, DateTime now) => sql(
      'UPDATE refresh_tokens SET revoked_at = :now '
      'WHERE token_hash = :h AND revoked_at IS NULL',
      {'h': hashRefreshToken(token), 'now': sqlDateTime(now)});

  /// Гасит все ещё живые токены цепочки; возвращает, сколько погасил.
  Future<int> revokeFamily(
      SqlExecutor sql, String family, DateTime now) async {
    final r = await sql(
        'UPDATE refresh_tokens SET revoked_at = :now '
        'WHERE family = :f AND revoked_at IS NULL',
        {'f': family, 'now': sqlDateTime(now)});
    return r.affectedRows.toInt();
  }

  Future<void> revokeAllForUser(
          SqlExecutor sql, String userUuid, DateTime now) =>
      sql(
          'UPDATE refresh_tokens SET revoked_at = :now '
          'WHERE user_uuid = :u AND revoked_at IS NULL',
          {'u': userUuid, 'now': sqlDateTime(now)});

  /// Старые записи больше не нужны даже для поиска повторного
  /// использования: удаляем истёкшие больше [keep] назад.
  Future<void> deleteExpired(SqlExecutor sql, DateTime now,
          {Duration keep = const Duration(days: 30)}) =>
      sql('DELETE FROM refresh_tokens WHERE expires_at < :t',
          {'t': sqlDateTime(now.subtract(keep))});
}
