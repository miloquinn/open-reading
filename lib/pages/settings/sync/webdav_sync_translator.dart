import 'package:flutter/widgets.dart';
import 'package:xxread/services/sync/sync_models.dart';
import 'package:xxread/utils/localization_extension.dart';

String webDavSyncErrorText(
  BuildContext context,
  WebDavSyncErrorCode? code,
) {
  switch (code) {
    case WebDavSyncErrorCode.authentication:
      return context.l10n.webDavErrorAuthentication;
    case WebDavSyncErrorCode.permissionDenied:
      return context.l10n.webDavErrorPermission;
    case WebDavSyncErrorCode.timeout:
      return context.l10n.webDavErrorTimeout;
    case WebDavSyncErrorCode.tls:
      return context.l10n.webDavErrorCertificate;
    case WebDavSyncErrorCode.network:
      return context.l10n.webDavErrorNetwork;
    case WebDavSyncErrorCode.serverIncompatible:
      return context.l10n.webDavErrorUnsupported;
    case WebDavSyncErrorCode.corruptRemoteData:
      return context.l10n.webDavErrorCorruptData;
    case WebDavSyncErrorCode.invalidConfiguration:
    case WebDavSyncErrorCode.insecureConnection:
    case WebDavSyncErrorCode.notFound:
    case WebDavSyncErrorCode.conflict:
    case WebDavSyncErrorCode.storageFull:
    case WebDavSyncErrorCode.rateLimited:
    case WebDavSyncErrorCode.clockSkew:
    case WebDavSyncErrorCode.secureStorage:
    case WebDavSyncErrorCode.unknown:
    case null:
      return context.l10n.webDavErrorUnknown;
  }
}
