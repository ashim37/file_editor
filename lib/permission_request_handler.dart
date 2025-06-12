import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

Future<void> requestStoragePermission() async {
  if (Platform.isAndroid) {
    var isManageExternalStorageGranted =
        await Permission.manageExternalStorage.isGranted;
    var isStorageGranted = await Permission.storage.isGranted;
    if (!isManageExternalStorageGranted) {
      await Permission.manageExternalStorage.request(); // Android 11+
    }
    if (!isStorageGranted) {
      await Permission.storage.request();
    }
  }
}
