// 文件说明：BookImportFailure code -> 用户可见文案的 i18n 翻译器。
// 技术要点：服务层抛出 code，UI 层调用此函数获得本地化文案。

import 'package:flutter/widgets.dart';
import '../../utils/localization_extension.dart';
import 'book_import_models.dart';

/// 把 [BookImportFailure.code] 翻译为用户可见的错误描述。
///
/// 服务层只抛出稳定的 `code`（如 `source_missing`、`hash_failed`），
/// UI 层在需要展示时调用此函数获得翻译后的文案。未匹配的 code
/// 回退到通用错误描述 [AppLocalizations.importErrorFailed]。
String translateBookImportFailure(
  BuildContext context,
  BookImportFailure failure,
) {
  final l10n = context.l10n;
  switch (failure.code) {
    case 'source_missing':
      return l10n.importErrorSourceMissing;
    case 'hash_failed':
      return l10n.importErrorHashFailed;
    case 'target_name_exhausted':
      return l10n.importErrorTargetNameExhausted;
    case 'source_not_materialized':
      return l10n.importErrorSourceNotMaterialized;
    case 'copy_verification_failed':
      return l10n.importErrorCopyVerificationFailed;
    case 'file_too_large':
      return l10n.importErrorFileTooLarge;
    case 'source_prepare_failed':
      return l10n.importErrorSourcePrepareFailed;
    default:
      return l10n.importErrorFailed;
  }
}
