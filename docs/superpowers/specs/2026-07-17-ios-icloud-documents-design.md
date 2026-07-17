# iOS iCloud Documents Capability Design

## Goal

Enable the iOS Runner target to use an app-owned iCloud Documents container for book files while preserving the existing local Files integration under `On My iPhone/Open Reading`.

This change establishes the signed platform capability and container contract. Directory scanning, book indexing, reading-progress synchronization, and import-page UI changes are separate follow-up work.

## Current State

- The Runner bundle identifier is `com.niki.xxread`.
- Automatic signing uses development team `2HD5836RZ2`.
- `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are already enabled in `ios/Runner/Info.plist`.
- The Runner target has no entitlements file and no iCloud capability configuration.
- Local imported books are stored under the application Documents directory in `books/`.

## Capability Contract

The Runner target will declare iCloud Documents support for the container:

`iCloud.com.niki.xxread`

The target will use the following entitlement categories:

- iCloud service: Cloud Documents.
- iCloud container association: `iCloud.com.niki.xxread`.
- Ubiquity container association for document storage.
- Ubiquity key-value store identifier generated from the configured team and bundle identifiers when required by Xcode signing.

Xcode project metadata will mark iCloud as an enabled system capability so the project UI and the signed entitlements describe the same configuration.

## Public iCloud Documents Scope

The iCloud container will be configured as a public document scope named `Open Reading`, with folder nesting allowed. Book files will live under:

`Documents/books/`

This keeps the iCloud layout consistent with the existing local application Documents layout and leaves room for future app-owned document categories.

The app will not migrate existing local books into iCloud as part of this capability-only change. It will also not silently delete, move, upload, or download user files.

## Files Changed During Implementation

- Create `ios/Runner/Runner.entitlements` for the Runner target entitlements.
- Update `ios/Runner.xcodeproj/project.pbxproj` to attach the entitlements file to Debug, Profile, and Release configurations and enable the iCloud system capability.
- Update `ios/Runner/Info.plist` with the public ubiquity-container presentation metadata if Xcode does not generate equivalent configuration.

No Flutter dependencies will be added for the capability-only change.

## Signing and Provisioning

The project will keep automatic signing. Verification will allow Xcode to update provisioning resources so the App ID and provisioning profile can include the iCloud container.

If Apple Developer account state prevents automatic provisioning, implementation will stop after preserving the local project changes and report the precise account-side blocker. Examples include an unsigned-in account, insufficient team role, an unaccepted agreement, or an unavailable container identifier.

No alternate container identifier will be chosen automatically because changing it would create a persistent external data namespace.

## Verification

Implementation is complete when all of the following hold:

1. `plutil` validates the entitlements and Info.plist files.
2. Every Runner build configuration references the same entitlements file.
3. The Xcode project declares iCloud as enabled for the Runner target.
4. A signed iOS build or Xcode build-settings inspection confirms that the effective entitlements contain the intended iCloud container and Cloud Documents service.
5. Existing local file-sharing keys remain enabled.
6. No unrelated dirty workspace files are staged or committed.

Real-device visibility under iCloud Drive requires a signed build installed on a device whose Apple ID has iCloud Drive enabled. Simulator-only verification is insufficient for that final behavior.

## Failure and Rollback

The capability change is reversible by removing the Runner entitlements reference, iCloud system-capability metadata, and public ubiquity-container metadata. Removing the local capability configuration does not delete files already present in an Apple-hosted iCloud container.

Provisioning failures must not be worked around by disabling signing checks, changing the bundle identifier, or committing development-team substitutions.

## Deferred Work

- Native API for resolving the ubiquity-container URL.
- Download-state handling for iCloud placeholder files.
- Directory scanning and incremental book indexing.
- Import-page UI and progress reporting.
- Cross-device reading progress, notes, or database synchronization.
- Migration of existing local books into iCloud.
