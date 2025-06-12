import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> getExportPath(String filename) async {
  if (Platform.isAndroid) {
    final downloads = Directory('/storage/emulated/0/Download');
    return '${downloads.path}/$filename';
  } else {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$filename'; // iOS Files app location
  }
}
