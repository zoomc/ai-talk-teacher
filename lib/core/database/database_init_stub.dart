// No-op stub used on non-web platforms. The web build swaps in
// database_init_web.dart via the conditional import in
// database_helper.dart.
void initDatabaseFactory() {
  // On native platforms (Android/iOS) sqflite already has its platform
  // channel factory registered — nothing to do.
}
