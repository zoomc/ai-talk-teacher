// Web-only implementation of the sqflite database factory init.
// Uses sqflite_common_ffi_web's WebAssembly-based SQLite to work
// in the browser.
//
// On non-web platforms this file is not compiled in — the conditional
// import in database_helper.dart picks the stub instead.

import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;

void initDatabaseFactory() {
  // Replace the default (platform-channel) factory with the web FFI one
  // that runs SQLite via WebAssembly inside the browser.
  databaseFactory = databaseFactoryFfiWeb;
}
