# Share Extension provisioning scaffold

The files in this directory are intentionally not attached to an Xcode target. Enabling the
extension requires an App Group identifier and provisioning profiles approved for both the main
application and the extension; do not invent or silently replace that identifier.

When provisioning is available, create a Share Extension target and apply these settings:

- Use `Info.plist.template` as the target Info.plist after replacing the template suffix.
- Use `ShareExtension.entitlements.template` as the entitlement source after replacing the
  template suffix.
- Set `OPEN_READING_APP_GROUP` to the same approved App Group identifier for Runner and the Share
  Extension, and add that App Group capability to both targets.
- Set `APPLICATION_EXTENSION_API_ONLY = YES` in every Share Extension build configuration.
- Give the extension its own bundle identifier and matching provisioning profile.
- Add the extension product to Runner's **Embed App Extensions** build phase with destination
  `PlugIns`; enable `Code Sign On Copy` for signed device/archive builds.
- Add `OpenReadingAppGroupIdentifier = $(OPEN_READING_APP_GROUP)` to Runner's Info.plist only when
  the Runner entitlement and provisioning profile contain the same App Group.

The main application already consumes the shared `IncomingBooks/manifests` inbox when that Info
key and entitlement are present. A Share Extension cannot reliably force-launch its containing
application; its supported contract is to add files to the inbox for the next app activation.
