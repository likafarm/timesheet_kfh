/// Версии программ, которые раздаёт сервер (`GET /client/version`, шаг 4.8):
/// последняя (с адресом загрузки) и минимальная — старее неё программа
/// работать с сервером не должна.
library;

/// Ошибка формата списка версий.
class ClientVersionsFormatException implements Exception {
  final String message;
  const ClientVersionsFormatException(this.message);

  @override
  String toString() => 'Неверный список версий: $message';
}

final _versionPattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');

/// Версия `X.Y.Z` (номер сборки `+N` отбрасывается) — список чисел; null,
/// если строка не версия.
List<int>? parseVersion(String version) {
  final m = _versionPattern.firstMatch(version.split('+').first.trim());
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
}

/// Сравнение версий `X.Y.Z`: <0 — [a] старее, 0 — равны, >0 — новее.
int compareVersions(String a, String b) {
  final x = parseVersion(a), y = parseVersion(b);
  if (x == null || y == null) {
    throw ClientVersionsFormatException('не версия: «${x == null ? a : b}»');
  }
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return 0;
}

/// Версии одной платформы.
class PlatformVersion {
  /// Последняя выпущенная версия.
  final String latest;

  /// Минимальная версия, с которой можно работать с сервером.
  final String min;

  /// Где скачать последнюю версию (null — обновление ставится иначе).
  final String? url;

  /// SHA-256 файла по [url] (для проверки загрузки человеком).
  final String? sha256;

  const PlatformVersion({
    required this.latest,
    required this.min,
    this.url,
    this.sha256,
  });

  factory PlatformVersion.fromJson(String platform, Object? json) {
    if (json is! Map) {
      throw ClientVersionsFormatException('$platform: не объект');
    }
    String version(String key) {
      final v = json[key];
      if (v is! String || parseVersion(v) == null) {
        throw ClientVersionsFormatException('$platform.$key: не версия X.Y.Z');
      }
      return v;
    }

    String? text(String key) {
      final v = json[key];
      if (v == null) return null;
      if (v is! String || v.isEmpty) {
        throw ClientVersionsFormatException('$platform.$key: не строка');
      }
      return v;
    }

    final result = PlatformVersion(
      latest: version('latest'),
      min: version('min'),
      url: text('url'),
      sha256: text('sha256'),
    );
    if (compareVersions(result.min, result.latest) > 0) {
      throw ClientVersionsFormatException(
        '$platform: минимальная версия новее последней',
      );
    }
    return result;
  }

  Map<String, Object?> toJson() => {
    'latest': latest,
    'min': min,
    if (url != null) 'url': url,
    if (sha256 != null) 'sha256': sha256,
  };

  /// Программе версии [current] нужно обновиться, чтобы работать.
  bool requiresUpdate(String current) => compareVersions(current, min) < 0;

  /// Есть версия новее [current].
  bool hasUpdate(String current) => compareVersions(current, latest) < 0;
}

/// Версии по платформам (`android`, `windows`).
class ClientVersions {
  final Map<String, PlatformVersion> platforms;

  const ClientVersions(this.platforms);

  static const empty = ClientVersions({});

  factory ClientVersions.fromJson(Object? json) {
    if (json is! Map) throw const ClientVersionsFormatException('не объект');
    final platforms = json['platforms'];
    if (platforms is! Map) {
      throw const ClientVersionsFormatException('нет объекта platforms');
    }
    return ClientVersions({
      for (final MapEntry(:key, :value) in platforms.entries)
        key as String: PlatformVersion.fromJson(key, value),
    });
  }

  Map<String, Object?> toJson() => {
    'platforms': {
      for (final e in platforms.entries) e.key: e.value.toJson(),
    },
  };
}
