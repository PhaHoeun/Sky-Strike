import Foundation
import SceneKit

#if os(iOS)
import Flutter
import UIKit
typealias JetPlatformColor = UIColor
typealias JetSceneScalar = Float
#elseif os(macOS)
import AppKit
import FlutterMacOS
typealias JetPlatformColor = NSColor
typealias JetSceneScalar = CGFloat
#endif

private func argbToPlatformColor(_ argb: Int, alphaOverride: CGFloat? = nil) -> JetPlatformColor {
  let a = alphaOverride ?? (CGFloat((argb >> 24) & 0xFF) / 255.0)
  let r = CGFloat((argb >> 16) & 0xFF) / 255.0
  let g = CGFloat((argb >> 8) & 0xFF) / 255.0
  let b = CGFloat(argb & 0xFF) / 255.0
  return JetPlatformColor(red: r, green: g, blue: b, alpha: a)
}

/// Shared material, studio lighting, and cloning helpers used by both the live
/// 360-degree Hangar showcase and the Metal Battle Sprite renderer so combat aircraft
/// match the selected Hangar jet visually across livery, canopy tint, and lighting.
enum Jet3dAppearance {
  static let camoPresets: [String: (rgb: (CGFloat, CGFloat, CGFloat), boost: CGFloat, metal: CGFloat)] = [
    "ARCTIC GHOST": ((0.92, 0.96, 1.00), 1.55, -0.08),
    "APEX ORANGE": ((0.88, 0.90, 0.94), 1.24, 0.02),
    "NIGHTHAWK": ((0.68, 0.74, 0.84), 1.15, 0.05),
    "OBSIDIAN NAVY": ((0.72, 0.84, 1.00), 1.32, 0.02),
    "DIGITAL FLANKER": ((0.96, 0.99, 1.00), 1.30, -0.04),
    "EXPERIMENTAL TITANIUM": ((1.00, 0.97, 0.90), 1.34, 0.08),
  ]

  static func collectMaterials(
    under root: SCNNode
  ) -> (
    hull: [SCNMaterial],
    canopy: [SCNMaterial],
    nozzle: [SCNMaterial],
    outerRim: [SCNMaterial],
    innerRim: [SCNMaterial]
  ) {
    var hull: [SCNMaterial] = []
    var canopy: [SCNMaterial] = []
    var nozzle: [SCNMaterial] = []
    var outerRim: [SCNMaterial] = []
    var innerRim: [SCNMaterial] = []

    root.enumerateHierarchy { node, _ in
      guard let mats = node.geometry?.materials else { return }
      for mat in mats {
        switch mat.name {
        case "hull_skin":
          hull.append(mat)
        case "canopy_glass":
          canopy.append(mat)
        case "nozzle_core":
          nozzle.append(mat)
        case "pedestal_outer_rim":
          outerRim.append(mat)
        case "pedestal_inner_rim":
          innerRim.append(mat)
        default:
          break
        }
      }
    }
    return (hull, canopy, nozzle, outerRim, innerRim)
  }

  static func cloneWithUniqueMaterials(_ source: SCNNode) -> SCNNode {
    let copy = source.clone()
    copy.enumerateHierarchy { node, _ in
      guard let geom = node.geometry else { return }
      if let g = geom.copy() as? SCNGeometry {
        g.materials = g.materials.compactMap { $0.copy() as? SCNMaterial }
        node.geometry = g
      }
    }
    return copy
  }

  static func configureStudioLights(
    on scene: SCNScene,
    forChaseView: Bool,
    castsShadow: Bool
  ) {
    scene.background.contents = JetPlatformColor.clear

    // Omnidirectional hangar skylight fill prevents crushed blacks on any 360-degree angle.
    let ambientLight = SCNLight()
    ambientLight.type = .ambient
    ambientLight.color = JetPlatformColor(red: 0.78, green: 0.88, blue: 0.98, alpha: 1.0)
    ambientLight.intensity = forChaseView ? 360 : 440
    let ambientNode = SCNNode()
    ambientNode.light = ambientLight
    scene.rootNode.addChildNode(ambientNode)

    let keyLight = SCNLight()
    keyLight.type = .directional
    keyLight.color = JetPlatformColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0)
    keyLight.intensity = forChaseView ? 1160 : 1280
    keyLight.castsShadow = castsShadow
    if castsShadow {
      keyLight.shadowRadius = 5.5
      keyLight.shadowSampleCount = 8
      keyLight.shadowColor = JetPlatformColor.black.withAlphaComponent(0.42)
    }
    let keyNode = SCNNode()
    keyNode.light = keyLight
    keyNode.eulerAngles = forChaseView
      ? SCNVector3(-0.88, 2.55, 0)
      : SCNVector3(-0.92, 0.42, 0)
    scene.rootNode.addChildNode(keyNode)

    // Camera-facing broadside spotlight keeps wings, intakes, and panel seams clear while spinning.
    let frontFillLight = SCNLight()
    frontFillLight.type = .directional
    frontFillLight.color = JetPlatformColor(red: 0.90, green: 0.95, blue: 1.0, alpha: 1.0)
    frontFillLight.intensity = forChaseView ? 500 : 620
    let frontFillNode = SCNNode()
    frontFillNode.light = frontFillLight
    frontFillNode.eulerAngles = forChaseView
      ? SCNVector3(-0.36, 3.05, 0)
      : SCNVector3(-0.26, -0.22, 0)
    scene.rootNode.addChildNode(frontFillNode)

    // Deck reflection under-bounce illuminates wing undersides, engine nacelles, and belly details.
    let bounceLight = SCNLight()
    bounceLight.type = .directional
    bounceLight.color = JetPlatformColor(red: 0.64, green: 0.88, blue: 1.0, alpha: 1.0)
    bounceLight.intensity = forChaseView ? 480 : 640
    let bounceNode = SCNNode()
    bounceNode.light = bounceLight
    bounceNode.eulerAngles = SCNVector3(0.62, 0.55, 0)
    scene.rootNode.addChildNode(bounceNode)

    let fillLight = SCNLight()
    fillLight.type = .directional
    fillLight.color = JetPlatformColor(red: 1.0, green: 0.91, blue: 0.80, alpha: 1.0)
    fillLight.intensity = forChaseView ? 440 : 580
    let fillNode = SCNNode()
    fillNode.light = fillLight
    fillNode.eulerAngles = forChaseView
      ? SCNVector3(-0.42, -1.95, 0)
      : SCNVector3(-0.38, -1.92, 0)
    scene.rootNode.addChildNode(fillNode)

    let rimLight = SCNLight()
    rimLight.type = .directional
    rimLight.color = JetPlatformColor(red: 0.74, green: 0.93, blue: 1.0, alpha: 1.0)
    rimLight.intensity = forChaseView ? 380 : 540
    let rimNode = SCNNode()
    rimNode.light = rimLight
    rimNode.eulerAngles = forChaseView
      ? SCNVector3(-0.30, -0.55, 0)
      : SCNVector3(-0.26, 2.65, 0)
    scene.rootNode.addChildNode(rimNode)
  }

  static func applyLivery(
    hullMaterials: [SCNMaterial],
    canopyMaterials: [SCNMaterial],
    nozzleMaterials: [SCNMaterial],
    outerRimMaterials: [SCNMaterial] = [],
    innerRimMaterials: [SCNMaterial] = [],
    jetId: String,
    camo: String,
    unlocked: Bool,
    trimArgb: Int,
    canopyArgb: Int,
    afterburnerArgb: Int
  ) {
    let selected = camoPresets[camo] ?? ((1.00, 1.00, 1.00), 1.12, -0.02)
    let mulRgb = selected.rgb
    // Keep locked aircraft brightly inspectable in Hangar instead of crushing geometry into shadow.
    let lockScale: CGFloat = unlocked ? 1.0 : 0.88
    let mulColor = JetPlatformColor(
      red: mulRgb.0 * lockScale,
      green: mulRgb.1 * lockScale,
      blue: mulRgb.2 * lockScale,
      alpha: 1.0
    )

    let baseMetal: CGFloat = (jetId == "su57" ? 0.14 : 0.20)
    let targetMetal = max(0.06, min(0.36, baseMetal + selected.metal))
    let softLiftColor = JetPlatformColor(
      red: 0.045 * mulRgb.0,
      green: 0.055 * mulRgb.1,
      blue: 0.075 * mulRgb.2,
      alpha: 1.0
    )

    for mat in hullMaterials {
      mat.multiply.contents = mulColor
      mat.diffuse.intensity = selected.boost * (unlocked ? 1.0 : 0.94)
      mat.metalness.contents = targetMetal
      mat.emission.contents = softLiftColor
    }

    let canopyColor = argbToPlatformColor(canopyArgb, alphaOverride: unlocked ? 0.72 : 0.58)
    for mat in canopyMaterials {
      mat.diffuse.contents = canopyColor
    }

    let burnColor = argbToPlatformColor(afterburnerArgb, alphaOverride: unlocked ? 0.85 : 0.34)
    for mat in nozzleMaterials {
      mat.emission.contents = burnColor
    }

    let outerAlpha: CGFloat = unlocked ? 0.92 : 0.58
    let outerColor = JetPlatformColor(red: 1.0, green: 0.44, blue: 0.04, alpha: outerAlpha)
    for mat in outerRimMaterials {
      mat.diffuse.contents = outerColor
      mat.emission.contents = outerColor
    }

    let innerColor = argbToPlatformColor(trimArgb, alphaOverride: unlocked ? 0.90 : 0.58)
    for mat in innerRimMaterials {
      mat.diffuse.contents = innerColor
      mat.emission.contents = innerColor
    }
  }
}

/// Caches decoded `.scn` scenes per jet ID so switching aircraft across
/// hangar slots is instantaneous without redundant file deserialization.
final class Jet3dSceneCache {
  static let shared = Jet3dSceneCache()
  private var cache: [String: SCNScene] = [:]

  private init() {}

  func scene(for jetId: String, lookupAsset: (String) -> String) -> SCNScene? {
    if let existing = cache[jetId] {
      return existing
    }
    let assetPath = "assets/models/\(jetId).scn"
    let assetKey = lookupAsset(assetPath)

    let candidateUrls: [URL?] = [
      Bundle.main.url(forResource: assetKey, withExtension: nil),
      Bundle.main.bundleURL.appendingPathComponent(assetKey),
      Bundle.main.privateFrameworksURL?
        .appendingPathComponent("App.framework/Resources/flutter_assets")
        .appendingPathComponent(assetKey),
      Bundle.main.privateFrameworksURL?
        .appendingPathComponent("App.framework/Resources/flutter_assets")
        .appendingPathComponent(assetPath),
      Bundle.main.privateFrameworksURL?
        .appendingPathComponent("App.framework/flutter_assets")
        .appendingPathComponent(assetKey),
      Bundle.main.bundleURL
        .appendingPathComponent("Frameworks/App.framework/flutter_assets")
        .appendingPathComponent(assetPath),
    ]

    for case let url? in candidateUrls where FileManager.default.fileExists(atPath: url.path) {
      if let loaded = try? SCNScene(url: url, options: nil) {
        cache[jetId] = loaded
        return loaded
      }
    }
    return nil
  }
}

/// Manages a live 3D SceneKit fighter aircraft + dark hex turntable inside an `SCNView`,
/// exposing sub-degree yaw/pitch rotation and live PBR camo material updates over MethodChannel.
final class Jet3dSceneController: NSObject {
  let scnView: SCNView
  private let lookupAsset: (String) -> String
  private var channel: FlutterMethodChannel?

  private let scene = SCNScene()
  private let cameraNode = SCNNode()
  private var aircraftNode: SCNNode?
  private var pedestalNode: SCNNode?

  private var hullMaterials: [SCNMaterial] = []
  private var canopyMaterials: [SCNMaterial] = []
  private var nozzleMaterials: [SCNMaterial] = []
  private var outerRimMaterials: [SCNMaterial] = []
  private var innerRimMaterials: [SCNMaterial] = []

  private var currentJetId: String = ""
  private var currentCamo: String = "STEALTH SLATE"
  private var isUnlocked: Bool = true
  private var trimArgb: Int = 0xFFFF6B00
  private var canopyArgb: Int = 0xFF24455E
  private var afterburnerArgb: Int = 0xFFFE7A1A
  private var yawDeg: Double = 45.0
  private var pitchDeg: Double = 0.0

  init(
    frame: CGRect,
    messenger: FlutterBinaryMessenger,
    viewId: Int64,
    args: [String: Any]?,
    lookupAsset: @escaping (String) -> String
  ) {
    self.scnView = SCNView(frame: frame)
    self.lookupAsset = lookupAsset
    super.init()

    configureView()
    configureStudioRig()
    applyArguments(args)

    let methodChannel = FlutterMethodChannel(
      name: "com.fightingjet/jet3d_\(viewId)",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handleMethodCall(call, result: result)
    }
    self.channel = methodChannel
  }

  deinit {
    channel?.setMethodCallHandler(nil)
    scnView.scene = nil
  }

  private func configureView() {
    scnView.scene = scene
    scnView.backgroundColor = .clear
    #if os(iOS)
    scnView.isOpaque = false
    scnView.isUserInteractionEnabled = false
    #elseif os(macOS)
    scnView.wantsLayer = true
    scnView.layer?.isOpaque = false
    scnView.layer?.backgroundColor = NSColor.clear.cgColor
    #endif
    scnView.antialiasingMode = .multisampling4X
    scnView.autoenablesDefaultLighting = false
    scnView.allowsCameraControl = false
    scnView.rendersContinuously = false
  }

  private func configureStudioRig() {
    let camera = SCNCamera()
    camera.fieldOfView = 25.5
    camera.zNear = 0.2
    camera.zFar = 45.0
    cameraNode.camera = camera
    scene.rootNode.addChildNode(cameraNode)
    scnView.pointOfView = cameraNode

    Jet3dAppearance.configureStudioLights(on: scene, forChaseView: false, castsShadow: true)
  }

  private func applyArguments(_ args: [String: Any]?) {
    guard let args = args else {
      loadJet(id: "f22")
      applyOrientation()
      return
    }
    let jetId = (args["jetId"] as? String) ?? "f22"
    currentCamo = (args["camo"] as? String) ?? currentCamo
    isUnlocked = (args["unlocked"] as? Bool) ?? true
    trimArgb = (args["trimArgb"] as? Int) ?? trimArgb
    canopyArgb = (args["canopyArgb"] as? Int) ?? canopyArgb
    afterburnerArgb = (args["afterburnerArgb"] as? Int) ?? afterburnerArgb
    yawDeg = (args["yawDeg"] as? Double) ?? yawDeg
    pitchDeg = (args["pitchDeg"] as? Double) ?? pitchDeg

    loadJet(id: jetId)
    applyCamoMaterials()
    applyOrientation()
  }

  private func loadJet(id jetId: String) {
    guard jetId != currentJetId || aircraftNode == nil else { return }
    currentJetId = jetId

    aircraftNode?.removeFromParentNode()
    pedestalNode?.removeFromParentNode()
    hullMaterials.removeAll()
    canopyMaterials.removeAll()
    nozzleMaterials.removeAll()
    outerRimMaterials.removeAll()
    innerRimMaterials.removeAll()

    guard let template = Jet3dSceneCache.shared.scene(for: jetId, lookupAsset: lookupAsset) else {
      return
    }

    if let env = template.lightingEnvironment.contents {
      scene.lightingEnvironment.contents = env
      scene.lightingEnvironment.intensity = 1.85
    }

    if let srcJet = template.rootNode.childNode(withName: "aircraft_root", recursively: true) {
      let clonedJet = Jet3dAppearance.cloneWithUniqueMaterials(srcJet)
      scene.rootNode.addChildNode(clonedJet)
      aircraftNode = clonedJet
      let mats = Jet3dAppearance.collectMaterials(under: clonedJet)
      hullMaterials.append(contentsOf: mats.hull)
      canopyMaterials.append(contentsOf: mats.canopy)
      nozzleMaterials.append(contentsOf: mats.nozzle)
    }

    if let srcPedestal = template.rootNode.childNode(withName: "hangar_pedestal", recursively: true) {
      let clonedPedestal = Jet3dAppearance.cloneWithUniqueMaterials(srcPedestal)
      scene.rootNode.addChildNode(clonedPedestal)
      pedestalNode = clonedPedestal
      let mats = Jet3dAppearance.collectMaterials(under: clonedPedestal)
      outerRimMaterials.append(contentsOf: mats.outerRim)
      innerRimMaterials.append(contentsOf: mats.innerRim)
    }
  }

  private func applyOrientation() {
    SCNTransaction.begin()
    SCNTransaction.animationDuration = 0.0
    SCNTransaction.disableActions = true

    let yawRad = JetSceneScalar(-yawDeg * Double.pi / 180.0)
    aircraftNode?.eulerAngles.y = yawRad
    pedestalNode?.eulerAngles.y = yawRad

    let elevDeg = max(6.0, min(44.0, 17.5 + pitchDeg))
    let elevRad = elevDeg * Double.pi / 180.0
    let dist = 7.15
    cameraNode.position = SCNVector3(
      JetSceneScalar(0),
      JetSceneScalar(sin(elevRad) * dist),
      JetSceneScalar(cos(elevRad) * dist)
    )
    cameraNode.look(at: SCNVector3(JetSceneScalar(0), JetSceneScalar(-0.09), JetSceneScalar(0)))

    SCNTransaction.commit()
  }

  private func applyCamoMaterials() {
    SCNTransaction.begin()
    SCNTransaction.animationDuration = 0.12
    Jet3dAppearance.applyLivery(
      hullMaterials: hullMaterials,
      canopyMaterials: canopyMaterials,
      nozzleMaterials: nozzleMaterials,
      outerRimMaterials: outerRimMaterials,
      innerRimMaterials: innerRimMaterials,
      jetId: currentJetId,
      camo: currentCamo,
      unlocked: isUnlocked,
      trimArgb: trimArgb,
      canopyArgb: canopyArgb,
      afterburnerArgb: afterburnerArgb
    )
    SCNTransaction.commit()
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "setOrientation":
      if let y = args?["yawDeg"] as? Double { yawDeg = y }
      if let p = args?["pitchDeg"] as? Double { pitchDeg = p }
      applyOrientation()
      result(nil)

    case "setJet":
      applyArguments(args)
      result(nil)

    case "setCamo":
      if let camo = args?["camo"] as? String { currentCamo = camo }
      if let unlocked = args?["unlocked"] as? Bool { isUnlocked = unlocked }
      if let t = args?["trimArgb"] as? Int { trimArgb = t }
      if let c = args?["canopyArgb"] as? Int { canopyArgb = c }
      if let a = args?["afterburnerArgb"] as? Int { afterburnerArgb = a }
      applyCamoMaterials()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

#if os(iOS)
final class Jet3dPlatformView: NSObject, FlutterPlatformView {
  private let controller: Jet3dSceneController

  init(
    frame: CGRect,
    viewId: Int64,
    args: Any?,
    registrar: FlutterPluginRegistrar
  ) {
    self.controller = Jet3dSceneController(
      frame: frame,
      messenger: registrar.messenger(),
      viewId: viewId,
      args: args as? [String: Any],
      lookupAsset: { registrar.lookupKey(forAsset: $0) }
    )
    super.init()
  }

  func view() -> UIView {
    controller.scnView
  }
}

final class Jet3dPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  private let registrar: FlutterPluginRegistrar

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    Jet3dPlatformView(frame: frame, viewId: viewId, args: args, registrar: registrar)
  }
}

#elseif os(macOS)
private final class Jet3dContainerNSView: NSView {
  private let controller: Jet3dSceneController

  init(viewId: Int64, args: Any?, registrar: FlutterPluginRegistrar) {
    self.controller = Jet3dSceneController(
      frame: CGRect(x: 0, y: 0, width: 400, height: 214),
      messenger: registrar.messenger,
      viewId: viewId,
      args: args as? [String: Any],
      lookupAsset: { registrar.lookupKey(forAsset: $0) }
    )
    super.init(frame: controller.scnView.frame)
    wantsLayer = true
    layer?.isOpaque = false
    controller.scnView.autoresizingMask = [.width, .height]
    controller.scnView.frame = bounds
    addSubview(controller.scnView)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    controller.scnView.frame = bounds
  }

  // Forward zero pointer hit tests so Flutter's overlay GestureDetector & scroll views win cleanly.
  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }
}

final class Jet3dPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  private let registrar: FlutterPluginRegistrar

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    Jet3dContainerNSView(viewId: viewId, args: args, registrar: registrar)
  }
}
#endif

/// Renders runtime 3D battle chase-cam sprites directly from the Hangar `.scn`
/// aircraft models so any camo selection in Hangar matches battle frame-for-frame.
final class Jet3dBattleSpriteChannel {
  private static var activeChannel: FlutterMethodChannel?
  private static let renderQueue = DispatchQueue(
    label: "com.fightingjet.battle_sprites",
    qos: .userInitiated
  )
  private static var renderedCache: [String: [String: FlutterStandardTypedData]] = [:]

  static func register(
    messenger: FlutterBinaryMessenger,
    lookupAsset: @escaping (String) -> String
  ) {
    let channel = FlutterMethodChannel(
      name: "com.fightingjet/battle_sprites",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "renderPlayerSprites",
            let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      renderPlayerSprites(args: args, lookupAsset: lookupAsset, result: result)
    }
    activeChannel = channel
  }

  private static func encodePng(_ image: Any) -> Data? {
    #if os(iOS)
    return (image as? UIImage)?.pngData()
    #elseif os(macOS)
    guard let nsImg = image as? NSImage,
          let tiff = nsImg.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else {
      return nil
    }
    return rep.representation(using: .png, properties: [:])
    #endif
  }

  private static func renderPlayerSprites(
    args: [String: Any],
    lookupAsset: @escaping (String) -> String,
    result: @escaping FlutterResult
  ) {
    let jetId = (args["jetId"] as? String) ?? "f22"
    let camo = (args["camo"] as? String) ?? "STEALTH SLATE"
    let unlocked = (args["unlocked"] as? Bool) ?? true
    let trimArgb = (args["trimArgb"] as? Int) ?? 0xFFFF6B00
    let canopyArgb = (args["canopyArgb"] as? Int) ?? 0xFF24455E
    let afterburnerArgb = (args["afterburnerArgb"] as? Int) ?? 0xFFFE7A1A

    let cacheKey = "\(jetId)|\(camo)|\(unlocked)|\(canopyArgb)|\(afterburnerArgb)"
    if let cached = renderedCache[cacheKey] {
      result(cached)
      return
    }

    guard let template = Jet3dSceneCache.shared.scene(for: jetId, lookupAsset: lookupAsset),
          let srcJet = template.rootNode.childNode(withName: "aircraft_root", recursively: true) else {
      result(nil)
      return
    }

    let envContents = template.lightingEnvironment.contents

    renderQueue.async {
      let scene = SCNScene()
      if let env = envContents {
        scene.lightingEnvironment.contents = env
        scene.lightingEnvironment.intensity = 1.45
      }
      Jet3dAppearance.configureStudioLights(on: scene, forChaseView: true, castsShadow: false)

      let clonedJet = Jet3dAppearance.cloneWithUniqueMaterials(srcJet)
      let mats = Jet3dAppearance.collectMaterials(under: clonedJet)
      Jet3dAppearance.applyLivery(
        hullMaterials: mats.hull,
        canopyMaterials: mats.canopy,
        nozzleMaterials: mats.nozzle,
        jetId: jetId,
        camo: camo,
        unlocked: unlocked,
        trimArgb: trimArgb,
        canopyArgb: canopyArgb,
        afterburnerArgb: afterburnerArgb
      )

      let holder = SCNNode()
      holder.addChildNode(clonedJet)
      scene.rootNode.addChildNode(holder)

      let cam = SCNCamera()
      cam.fieldOfView = 27.5
      cam.zNear = 0.2
      cam.zFar = 50.0
      let camNode = SCNNode()
      camNode.camera = cam

      let dist = 10.2
      let pitchRad = 40.0 * Double.pi / 180.0
      camNode.position = SCNVector3(
        JetSceneScalar(0),
        JetSceneScalar(sin(pitchRad) * dist),
        JetSceneScalar(-cos(pitchRad) * dist)
      )
      camNode.look(at: SCNVector3(JetSceneScalar(0), JetSceneScalar(0.02), JetSceneScalar(-0.22)))
      scene.rootNode.addChildNode(camNode)

      let renderer = SCNRenderer(device: nil, options: nil)
      renderer.scene = scene
      renderer.pointOfView = camNode

      let poses: [(String, Double)] = [
        ("m2", -34.0),
        ("m1", -17.0),
        ("0", 0.0),
        ("p1", 17.0),
        ("p2", 34.0),
      ]
      let targetSize = CGSize(width: 512, height: 512)
      var output: [String: FlutterStandardTypedData] = [:]

      for (label, deg) in poses {
        clonedJet.eulerAngles = SCNVector3(
          JetSceneScalar(0),
          JetSceneScalar(0),
          JetSceneScalar(deg * Double.pi / 180.0)
        )
        let img = renderer.snapshot(
          atTime: 0,
          with: targetSize,
          antialiasingMode: .multisampling4X
        )
        if let png = encodePng(img) {
          output[label] = FlutterStandardTypedData(bytes: png)
        }
      }

      DispatchQueue.main.async {
        if !output.isEmpty {
          renderedCache[cacheKey] = output
        }
        result(output.isEmpty ? nil : output)
      }
    }
  }
}
