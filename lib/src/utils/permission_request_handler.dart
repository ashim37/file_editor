import 'dart:io';

Future<bool> requestStoragePermission() async {
  // Since we're using app-specific storage directories that don't require permissions,
  // we can always return true. These directories are:
  // - getExternalStorageDirectory() on Android (app-specific, no permissions needed)
  // - getApplicationDocumentsDirectory() on iOS (app sandbox, no permissions needed)
  return true;
}
