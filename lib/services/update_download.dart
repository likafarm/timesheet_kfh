// lib/services/update_download.dart
//
// Загрузка установщика новой версии (этап 6.5): файл целиком в памяти (около
// 15 МБ), ход загрузки — для полосы, затем сверка SHA-256 с тем, что
// сообщил сервер (`versions.json`). Файл с другой суммой не запускается.

import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Загрузка не удалась — [message] для человека.
class UpdateException implements Exception {
  final String message;
  const UpdateException(this.message);

  @override
  String toString() => message;
}

/// Скачивает [url] и сверяет SHA-256 с [sha256]. [onProgress] — получено
/// байт и всего (null — сервер не сообщил размер).
Future<Uint8List> downloadVerified(
  http.Client client,
  Uri url,
  String sha256, {
  void Function(int received, int? total)? onProgress,
  Duration timeout = const Duration(minutes: 5),
}) async {
  final http.StreamedResponse response;
  try {
    response = await client
        .send(http.Request('GET', url))
        .timeout(const Duration(seconds: 30));
  } on TimeoutException {
    throw const UpdateException('Сервер не ответил — попробуйте позже');
  } on http.ClientException {
    throw const UpdateException('Нет связи с сервером — попробуйте позже');
  }
  if (response.statusCode != 200) {
    throw UpdateException(
      'Сервер не отдал обновление (HTTP ${response.statusCode})',
    );
  }
  final total = response.contentLength;
  final bytes = BytesBuilder(copy: false);
  try {
    await for (final chunk in response.stream.timeout(timeout)) {
      bytes.add(chunk);
      onProgress?.call(bytes.length, total);
    }
  } on TimeoutException {
    throw const UpdateException('Загрузка оборвалась — попробуйте позже');
  } on http.ClientException {
    throw const UpdateException('Загрузка оборвалась — попробуйте позже');
  }
  final data = bytes.takeBytes();
  if (total != null && data.length != total) {
    throw const UpdateException('Загрузка оборвалась — попробуйте позже');
  }
  final actual = sha256Of(data);
  if (actual != sha256.toLowerCase()) {
    throw const UpdateException(
      'Скачанный файл не совпал с контрольной суммой сервера — установка '
      'отменена. Попробуйте ещё раз; если повторится — сообщите '
      'администратору.',
    );
  }
  return data;
}

/// SHA-256 в виде строки из 64 шестнадцатеричных цифр.
String sha256Of(List<int> data) => sha256.convert(data).toString();
