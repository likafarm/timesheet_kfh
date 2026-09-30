import 'failures.dart';

/// Ежедневная выгрузка сервера для модуля «Резервные копии»
/// (`GET /admin/backups`, сервер 0.8.0+): снимок всех записей, сжатый и
/// зашифрованный ключом владельца (age).
class ServerBackup {
  /// Имя файла: `kfh-ГГГГММДД-ЧЧММСС.json.gz.age`.
  final String name;

  /// Размер зашифрованного файла, байт.
  final int size;

  /// Когда снята (UTC).
  final DateTime createdAt;

  const ServerBackup({
    required this.name,
    required this.size,
    required this.createdAt,
  });

  factory ServerBackup.fromJson(Object? json) {
    if (json is! Map ||
        json['name'] is! String ||
        json['size'] is! int ||
        DateTime.tryParse('${json['created_at']}') == null) {
      throw ServerFailure('неверная запись в списке копий');
    }
    return ServerBackup(
      name: json['name'] as String,
      size: json['size'] as int,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }
}
