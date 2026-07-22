import Flutter
import UIKit

@objc(SceneDelegate)
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    IncomingBookInbox.shared.accept(
      urls: connectionOptions.urlContexts.map(\.url),
      action: "open"
    )
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    IncomingBookInbox.shared.accept(
      urls: URLContexts.map(\.url),
      action: "open"
    )
    super.scene(scene, openURLContexts: URLContexts)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    IncomingBookInbox.shared.consumeSharedExtensionInboxIfConfigured()
  }
}
