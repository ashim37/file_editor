import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

Future<void> requestStoragePermission() async {
  if (Platform.isAndroid) {
    await Permission.manageExternalStorage.request(); // Android 11+
    await Permission.storage.request();
  }
}
