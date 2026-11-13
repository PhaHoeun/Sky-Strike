import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "Jet3dViewPlugin") {
      registrar.register(
        Jet3dPlatformViewFactory(registrar: registrar),
        withId: "com.fightingjet/jet_3d_view"
      )
      Jet3dBattleSpriteChannel.register(
        messenger: registrar.messenger(),
        lookupAsset: { registrar.lookupKey(forAsset: $0) }
      )
      BattleAudioChannel.register(messenger: registrar.messenger())
    }
  }
}
