const int maxOfficialApkSizeBytes = 512 * 1024 * 1024;

bool isValidOfficialApkFileSize(int fileSize) =>
    fileSize > 0 && fileSize <= maxOfficialApkSizeBytes;

bool isUpdateDownloadProgressOverLimit({
  required int received,
  required int total,
  required int expectedFileSize,
}) {
  if (!isValidOfficialApkFileSize(expectedFileSize)) return true;
  return received > expectedFileSize ||
      total > expectedFileSize ||
      received > maxOfficialApkSizeBytes ||
      total > maxOfficialApkSizeBytes;
}
