// Исходник web/drift_worker.js — фонового обработчика базы drift в
// браузере. Собирается tool/web_assets.ps1 из закреплённой версии drift
// (worker и приложение обязаны быть одной версии).

import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
