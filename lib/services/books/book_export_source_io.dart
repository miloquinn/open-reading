import 'dart:io';

Future<bool> bookExportSourceExists(String path) => File(path).exists();
