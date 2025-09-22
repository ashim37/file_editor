import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> getExportPath(String filename) async {
  if (Platform.isAndroid) {
    // Use app-specific external storage directory (doesn't require permissions)
    final directory = await getExternalStorageDirectory();
    if (directory != null) {
      return '${directory.path}/$filename';
    }

    // Fallback to app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$filename';
  } else {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$filename'; // iOS Files app location
  }
}
