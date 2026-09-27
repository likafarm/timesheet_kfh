import 'package:web/web.dart' as web;

/// Перезагрузить страницу: браузер сверит файлы с сервером (no-cache) и
/// загрузит новую версию программы; данные остаются в базе браузера.
void reloadPage() => web.window.location.reload();
