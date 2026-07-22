import 'package:flutter/widgets.dart';
import 'package:xxread/services/sync/sync_models.dart';
import 'package:xxread/utils/localization_extension.dart';

String webDavSyncErrorText(BuildContext context, WebDavSyncErrorCode? code) {
  switch (code) {
    case WebDavSyncErrorCode.invalidConfiguration:
      return context.l10n.webDavErrorInvalidConfiguration;
    case WebDavSyncErrorCode.insecureConnection:
      return context.l10n.webDavErrorInsecureConnection;
    case WebDavSyncErrorCode.authentication:
      return context.l10n.webDavErrorAuthentication;
    case WebDavSyncErrorCode.permissionDenied:
      return context.l10n.webDavErrorPermission;
    case WebDavSyncErrorCode.notFound:
      return context.l10n.webDavErrorNotFound;
    case WebDavSyncErrorCode.conflict:
      return context.l10n.webDavErrorConflict;
    case WebDavSyncErrorCode.timeout:
      return context.l10n.webDavErrorTimeout;
    case WebDavSyncErrorCode.tls:
      return context.l10n.webDavErrorCertificate;
    case WebDavSyncErrorCode.network:
      return context.l10n.webDavErrorNetwork;
    case WebDavSyncErrorCode.serverIncompatible:
      return context.l10n.webDavErrorUnsupported;
    case WebDavSyncErrorCode.storageFull:
      return context.l10n.webDavErrorStorageFull;
    case WebDavSyncErrorCode.rateLimited:
      return context.l10n.webDavErrorRateLimited;
    case WebDavSyncErrorCode.corruptRemoteData:
      return context.l10n.webDavErrorCorruptData;
    case WebDavSyncErrorCode.clockSkew:
      return context.l10n.webDavErrorClockSkew;
    case WebDavSyncErrorCode.secureStorage:
      return context.l10n.webDavErrorSecureStorage;
    case WebDavSyncErrorCode.unknown:
    case null:
      return context.l10n.webDavErrorUnknown;
  }
}

String webDavSyncFailurePhaseText(BuildContext context, WebDavSyncPhase phase) {
  final phaseText = switch (phase) {
    WebDavSyncPhase.connecting => context.l10n.webDavPhaseConnecting,
    WebDavSyncPhase.scanningLocal => context.l10n.webDavPhaseScanningLocal,
    WebDavSyncPhase.readingRemote => context.l10n.webDavPhaseReadingRemote,
    WebDavSyncPhase.applyingRemote => context.l10n.webDavPhaseApplyingRemote,
    WebDavSyncPhase.uploadingLocal => context.l10n.webDavPhaseUploadingLocal,
    WebDavSyncPhase.finishing => context.l10n.webDavPhaseFinishing,
    WebDavSyncPhase.none => context.l10n.webDavPhaseUnknown,
  };
  return context.l10n.webDavErrorPhase(phaseText);
}
