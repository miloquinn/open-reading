// Web 等无 dart:io 平台让请求继续到 unsupported 后端，避免把平台不支持
// 错报成“源文件丢失”。
Future<bool> bookExportSourceExists(String path) async => true;
