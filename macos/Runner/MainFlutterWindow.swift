import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let jet3dRegistrar = flutterViewController.registrar(forPlugin: "Jet3dViewPlugin")
    jet3dRegistrar.register(
      Jet3dPlatformViewFactory(registrar: jet3dRegistrar),
      withId: "com.fightingjet/jet_3d_view"
    )
    Jet3dBattleSpriteChannel.register(
      messenger: jet3dRegistrar.messenger,
      lookupAsset: { jet3dRegistrar.lookupKey(forAsset: $0) }
    )
    BattleAudioChannel.register(messenger: jet3dRegistrar.messenger)

    super.awakeFromNib()
  }
}
