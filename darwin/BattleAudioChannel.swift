import AVFoundation
import Foundation

#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

/// Native low-latency combat sound effects & looping jet-engine ambience
/// controller shared cleanly across iOS and macOS over `com.fightingjet/battle_audio`.
final class BattleAudioChannel {
  private static var activeChannel: FlutterMethodChannel?
  private static let shared = BattleAudioChannel()

  private let sampleRate: Double = 44100.0
  private lazy var monoFormat = AVAudioFormat(
    standardFormatWithSampleRate: sampleRate,
    channels: 1
  )!

  private let audioQueue = DispatchQueue(
    label: "com.fightingjet.battle_audio",
    qos: .userInteractive
  )
  private let engine = AVAudioEngine()
  private var sfxNodes: [AVAudioPlayerNode] = []
  private var nextNodeIndex = 0
  private let loopNode = AVAudioPlayerNode()

  private var buffers: [String: AVAudioPCMBuffer] = [:]
  private var loopBuffer: AVAudioPCMBuffer?
  private var engineConfigured = false
  private var sessionConfigured = false

  private var isMuted = false
  private var battleLoopActive = false
  private var battleLoopPaused = false
  private var battleLoopPlaying = false
  private var overdriveActive = false
  private var cannonVariant = 0

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.fightingjet/battle_audio",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setMuted":
        let muted = (call.arguments as? [String: Any])?["muted"] as? Bool ?? false
        shared.setMuted(muted)
        result(nil)
      case "playSfx":
        let name = (call.arguments as? [String: Any])?["name"] as? String ?? "ui_click"
        shared.playSfx(name)
        result(nil)
      case "startBattleLoop":
        let overdrive = (call.arguments as? [String: Any])?["overdrive"] as? Bool ?? false
        shared.startBattleLoop(overdrive: overdrive)
        result(nil)
      case "updateBattleLoop":
        let args = call.arguments as? [String: Any]
        let paused = args?["paused"] as? Bool ?? false
        let overdrive = args?["overdrive"] as? Bool ?? false
        shared.updateBattleLoop(paused: paused, overdrive: overdrive)
        result(nil)
      case "stopBattleLoop":
        shared.stopBattleLoop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    activeChannel = channel
  }

  private func ensureConfigured() -> Bool {
    if !sessionConfigured {
      sessionConfigured = true
      #if os(iOS)
      do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, options: [.mixWithOthers])
        try session.setActive(true)
      } catch {
        // Audio session failure on headless/restricted devices degrades silently.
      }
      #endif
    }

    if !engineConfigured {
      engineConfigured = true
      buildSoundBank()

      for _ in 0..<10 {
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: monoFormat)
        sfxNodes.append(node)
      }
      engine.attach(loopNode)
      engine.connect(loopNode, to: engine.mainMixerNode, format: monoFormat)
      engine.mainMixerNode.outputVolume = isMuted ? 0.0 : 0.92
    }

    if !engine.isRunning {
      do {
        engine.prepare()
        try engine.start()
      } catch {
        return false
      }
    }
    return true
  }

  func setMuted(_ muted: Bool) {
    audioQueue.async { [weak self] in
      guard let self else { return }
      self.isMuted = muted
      if self.engineConfigured {
        self.engine.mainMixerNode.outputVolume = muted ? 0.0 : 0.92
        if muted {
          for node in self.sfxNodes where node.isPlaying {
            node.stop()
          }
          if self.battleLoopPlaying {
            self.loopNode.pause()
            self.battleLoopPlaying = false
          }
        } else if self.battleLoopActive && !self.battleLoopPaused {
          self.scheduleOrResumeLoop()
        }
      }
    }
  }

  func playSfx(_ name: String) {
    audioQueue.async { [weak self] in
      guard let self, !self.isMuted else { return }
      guard self.ensureConfigured() else { return }

      var key = name
      if name == "cannon" {
        self.cannonVariant = (self.cannonVariant + 1) % 3
        key = "cannon_\(self.cannonVariant)"
      }

      guard let buf = self.buffers[key] ?? self.buffers[name] else { return }
      guard !self.sfxNodes.isEmpty else { return }

      let node = self.sfxNodes[self.nextNodeIndex]
      self.nextNodeIndex = (self.nextNodeIndex + 1) % self.sfxNodes.count
      if node.isPlaying {
        node.stop()
      }
      node.volume = self.gainForSfx(name)
      node.scheduleBuffer(buf, at: nil, options: .interrupts, completionHandler: nil)
      node.play()
    }
  }

  func startBattleLoop(overdrive: Bool) {
    audioQueue.async { [weak self] in
      guard let self else { return }
      self.battleLoopActive = true
      self.battleLoopPaused = false
      self.overdriveActive = overdrive
      guard !self.isMuted else { return }
      guard self.ensureConfigured() else { return }
      self.scheduleOrResumeLoop()
    }
  }

  func updateBattleLoop(paused: Bool, overdrive: Bool) {
    audioQueue.async { [weak self] in
      guard let self, self.battleLoopActive else { return }
      self.battleLoopPaused = paused
      self.overdriveActive = overdrive
      guard self.engineConfigured else { return }

      self.loopNode.volume = overdrive ? 0.42 : 0.25
      if paused || self.isMuted {
        if self.battleLoopPlaying {
          self.loopNode.pause()
          self.battleLoopPlaying = false
        }
      } else {
        guard self.ensureConfigured() else { return }
        self.scheduleOrResumeLoop()
      }
    }
  }

  func stopBattleLoop() {
    audioQueue.async { [weak self] in
      guard let self else { return }
      self.battleLoopActive = false
      self.battleLoopPaused = false
      self.battleLoopPlaying = false
      if self.engineConfigured && self.loopNode.isPlaying {
        self.loopNode.stop()
      }
    }
  }

  private func scheduleOrResumeLoop() {
    guard let buf = loopBuffer else { return }
    loopNode.volume = overdriveActive ? 0.42 : 0.25
    if !loopNode.isPlaying {
      loopNode.scheduleBuffer(buf, at: nil, options: .loops, completionHandler: nil)
    }
    loopNode.play()
    battleLoopPlaying = true
  }

  private func gainForSfx(_ name: String) -> Float {
    switch name {
    case "cannon": return 0.56
    case "missile": return 0.72
    case "explosion_small": return 0.74
    case "explosion_big": return 0.90
    case "player_hit": return 0.78
    case "shield_hit": return 0.65
    case "overdrive": return 0.80
    case "shield": return 0.64
    case "stage_clear": return 0.72
    case "defeat": return 0.76
    case "ui_click": return 0.55
    default: return 0.65
    }
  }

  // MARK: - Procedural DSP Waveform Synthesis

  private func buildSoundBank() {
    buffers["cannon_0"] = makeCannonBuffer(pitchMul: 0.96, seed: 11)
    buffers["cannon_1"] = makeCannonBuffer(pitchMul: 1.00, seed: 29)
    buffers["cannon_2"] = makeCannonBuffer(pitchMul: 1.06, seed: 47)
    buffers["missile"] = makeMissileBuffer()
    buffers["explosion_small"] = makeExplosionBuffer(duration: 0.42, baseFreq: 145, endFreq: 34, seed: 101)
    buffers["explosion_big"] = makeExplosionBuffer(duration: 1.10, baseFreq: 112, endFreq: 24, seed: 211)
    buffers["player_hit"] = makePlayerHitBuffer()
    buffers["shield_hit"] = makeShieldHitBuffer()
    buffers["overdrive"] = makeOverdriveBuffer()
    buffers["shield"] = makeShieldBuffer()
    buffers["stage_clear"] = makeStageClearBuffer()
    buffers["defeat"] = makeDefeatBuffer()
    buffers["ui_click"] = makeUiClickBuffer()
    loopBuffer = makeBattleAmbienceLoopBuffer()
  }

  private func makeBuffer(duration: Double, generator: (Int, Int) -> Float) -> AVAudioPCMBuffer? {
    let frameCount = Int(sampleRate * duration)
    guard let buf = AVAudioPCMBuffer(
      pcmFormat: monoFormat,
      frameCapacity: AVAudioFrameCount(frameCount)
    ),
    let ptr = buf.floatChannelData?[0] else {
      return nil
    }
    buf.frameLength = AVAudioFrameCount(frameCount)
    for i in 0..<frameCount {
      let s = generator(i, frameCount)
      ptr[i] = tanh(s * 0.95)
    }
    return buf
  }

  private func nextNoise(_ state: inout UInt32) -> Float {
    state ^= state << 13
    state ^= state >> 17
    state ^= state << 5
    return Float(Int32(bitPattern: state)) / Float(Int32.max)
  }

  private func makeCannonBuffer(pitchMul: Double, seed: UInt32) -> AVAudioPCMBuffer? {
    var rng: UInt32 = seed == 0 ? 1 : seed
    var phase = 0.0
    var lp: Float = 0.0
    var hpPrevIn: Float = 0.0
    var hpPrevOut: Float = 0.0

    return makeBuffer(duration: 0.082) { i, _ in
      let t = Double(i) / sampleRate
      let freq = (95.0 + 760.0 * exp(-t * 95.0)) * pitchMul
      phase += 2.0 * Double.pi * freq / sampleRate
      let thump = Float(sin(phase)) * Float(exp(-t * 48.0)) * 0.85

      let n = nextNoise(&rng)
      lp = lp * 0.62 + n * 0.38
      let hp = 0.86 * (hpPrevOut + lp - hpPrevIn)
      hpPrevIn = lp
      hpPrevOut = hp

      let crack = hp * Float(exp(-t * 68.0)) * 0.95
      return (thump + crack) * 0.78
    }
  }

  private func makeMissileBuffer() -> AVAudioPCMBuffer? {
    var rng: UInt32 = 307
    var phase = 0.0
    var chirpPhase = 0.0
    var lp: Float = 0.0

    return makeBuffer(duration: 0.48) { i, _ in
      let t = Double(i) / sampleRate
      let env = Float(min(1.0, t / 0.025) * exp(-max(0.0, t - 0.06) * 5.2))

      // Quick seeker lock chirrup in first 35ms
      var chirp: Float = 0.0
      if t < 0.038 {
        chirpPhase += 2.0 * Double.pi * 1980.0 / sampleRate
        chirp = Float(sin(chirpPhase)) * Float(1.0 - t / 0.038) * 0.25
      }

      // Rocket motor roar
      let f = 140.0 + 380.0 * (1.0 - exp(-t * 6.0))
      phase += 2.0 * Double.pi * f / sampleRate
      let roarOsc = Float(sin(phase)) * 0.38

      let n = nextNoise(&rng)
      let cutoff = Float(min(0.65, 0.14 + t * 0.95))
      lp = lp * (1.0 - cutoff) + n * cutoff
      return (roarOsc + lp * 0.95) * env + chirp
    }
  }

  private func makeExplosionBuffer(
    duration: Double,
    baseFreq: Double,
    endFreq: Double,
    seed: UInt32
  ) -> AVAudioPCMBuffer? {
    var rng: UInt32 = seed == 0 ? 99 : seed
    var phase = 0.0
    var lpLow: Float = 0.0
    var lpMid: Float = 0.0

    return makeBuffer(duration: duration) { i, _ in
      let t = Double(i) / sampleRate
      let attack = min(1.0, t / 0.008)
      let boomEnv = Float(attack * exp(-t * (duration > 0.7 ? 2.9 : 6.4)))

      let f = endFreq + (baseFreq - endFreq) * exp(-t * 14.0)
      phase += 2.0 * Double.pi * f / sampleRate
      let sub = Float(sin(phase)) * Float(exp(-t * 8.0)) * 0.92

      let n = nextNoise(&rng)
      lpLow = lpLow * 0.90 + n * 0.10
      lpMid = lpMid * 0.65 + n * 0.35
      let crackle = (n * 0.35 + lpMid * 0.75) * Float(exp(-t * (duration > 0.7 ? 3.5 : 8.2)))
      return sub + (lpLow * 0.95 + crackle * 0.7) * boomEnv
    }
  }

  private func makePlayerHitBuffer() -> AVAudioPCMBuffer? {
    var rng: UInt32 = 509
    var phase = 0.0
    var warnPhase = 0.0

    return makeBuffer(duration: 0.22) { i, _ in
      let t = Double(i) / sampleRate
      let f = 68.0 + 135.0 * exp(-t * 28.0)
      phase += 2.0 * Double.pi * f / sampleRate
      let thud = Float(sin(phase)) * Float(exp(-t * 16.0)) * 0.85

      warnPhase += 2.0 * Double.pi * 860.0 / sampleRate
      let beep = t < 0.07 ? Float(sin(warnPhase)) * 0.22 * Float(1.0 - t / 0.07) : 0.0
      let staticBurst = nextNoise(&rng) * Float(exp(-t * 24.0)) * 0.45
      return thud + staticBurst + beep
    }
  }

  private func makeShieldHitBuffer() -> AVAudioPCMBuffer? {
    var carrier = 0.0
    var mod = 0.0
    return makeBuffer(duration: 0.19) { i, _ in
      let t = Double(i) / sampleRate
      let f = 540.0 - 290.0 * (t / 0.19)
      mod += 2.0 * Double.pi * 110.0 / sampleRate
      carrier += 2.0 * Double.pi * (f + 85.0 * sin(mod)) / sampleRate
      let env = Float(exp(-t * 15.0))
      return Float(sin(carrier)) * env * 0.72
    }
  }

  private func makeOverdriveBuffer() -> AVAudioPCMBuffer? {
    var rng: UInt32 = 773
    var boomPhase = 0.0
    var whinePhase = 0.0
    var lp: Float = 0.0

    return makeBuffer(duration: 0.68) { i, _ in
      let t = Double(i) / sampleRate
      let boomFreq = 42.0 + 95.0 * exp(-t * 10.0)
      boomPhase += 2.0 * Double.pi * boomFreq / sampleRate
      let boom = Float(sin(boomPhase)) * Float(exp(-t * 5.0)) * 0.65

      let whineFreq = 320.0 + 1150.0 * min(1.0, t / 0.35)
      whinePhase += 2.0 * Double.pi * whineFreq / sampleRate
      let whineEnv = Float(min(1.0, t / 0.08) * exp(-max(0.0, t - 0.18) * 3.8))
      let whine = Float(sin(whinePhase)) * whineEnv * 0.26

      lp = lp * 0.78 + nextNoise(&rng) * 0.22
      let wash = lp * Float(min(1.0, t / 0.04) * exp(-max(0.0, t - 0.12) * 3.4)) * 0.75
      return boom + whine + wash
    }
  }

  private func makeShieldBuffer() -> AVAudioPCMBuffer? {
    var p1 = 0.0
    var p2 = 0.0
    return makeBuffer(duration: 0.36) { i, _ in
      let t = Double(i) / sampleRate
      let f1 = 290.0 + 340.0 * min(1.0, t / 0.28)
      p1 += 2.0 * Double.pi * f1 / sampleRate
      p2 += 2.0 * Double.pi * (f1 * 1.5) / sampleRate
      let env = Float(min(1.0, t / 0.04) * exp(-max(0.0, t - 0.06) * 7.5))
      return (Float(sin(p1)) * 0.6 + Float(sin(p2)) * 0.35) * env
    }
  }

  private func makeStageClearBuffer() -> AVAudioPCMBuffer? {
    let notes: [(start: Double, end: Double, freq: Double)] = [
      (0.00, 0.16, 523.25),
      (0.11, 0.30, 659.25),
      (0.22, 0.60, 783.99),
    ]
    var phases = [0.0, 0.0, 0.0]

    return makeBuffer(duration: 0.62) { i, _ in
      let t = Double(i) / sampleRate
      var sum: Float = 0.0
      for (idx, n) in notes.enumerated() where t >= n.start && t <= n.end {
        let localT = t - n.start
        phases[idx] += 2.0 * Double.pi * n.freq / sampleRate
        let env = Float(min(1.0, localT / 0.015) * exp(-localT * 8.0))
        sum += Float(sin(phases[idx]) + 0.3 * sin(phases[idx] * 2.0)) * env * 0.42
      }
      return sum
    }
  }

  private func makeDefeatBuffer() -> AVAudioPCMBuffer? {
    var phase = 0.0
    return makeBuffer(duration: 0.78) { i, _ in
      let t = Double(i) / sampleRate
      let f = 430.0 * exp(-t * 2.1)
      phase += 2.0 * Double.pi * f / sampleRate
      let env = Float(min(1.0, t / 0.03) * exp(-max(0.0, t - 0.12) * 2.8))
      return Float(sin(phase) * 0.65 + 0.25 * sin(phase * 0.5)) * env
    }
  }

  private func makeUiClickBuffer() -> AVAudioPCMBuffer? {
    var phase = 0.0
    return makeBuffer(duration: 0.048) { i, _ in
      let t = Double(i) / sampleRate
      let f = 540.0 + 960.0 * exp(-t * 110.0)
      phase += 2.0 * Double.pi * f / sampleRate
      return Float(sin(phase)) * Float(exp(-t * 72.0)) * 0.68
    }
  }

  private func makeBattleAmbienceLoopBuffer() -> AVAudioPCMBuffer? {
    let duration = 2.0
    let frameCount = Int(sampleRate * duration)
    var raw = [Float](repeating: 0, count: frameCount)
    var rng: UInt32 = 919
    var lpSlow: Float = 0.0
    var lpMid: Float = 0.0

    for i in 0..<frameCount {
      let t = Double(i) / sampleRate
      // Periodic harmonics exact integer cycles over 2.0 seconds -> seamless loop!
      let turbine = sin(2.0 * Double.pi * 62.0 * t) * 0.22
        + sin(2.0 * Double.pi * 93.0 * t) * 0.14
        + sin(2.0 * Double.pi * 124.0 * t) * 0.08
      let lfo = 0.85 + 0.15 * sin(2.0 * Double.pi * 0.5 * t)

      let n = nextNoise(&rng)
      lpSlow = lpSlow * 0.985 + n * 0.015
      lpMid = lpMid * 0.88 + n * 0.12
      let rumble = lpSlow * 1.45 + lpMid * 0.24
      raw[i] = Float(turbine * lfo) + rumble
    }

    // Crossfade end 100ms smoothly into start 100ms so filtered noise loops click-free
    let fadeSamples = Int(sampleRate * 0.10)
    for k in 0..<fadeSamples {
      let alpha = Float(k) / Float(fadeSamples)
      let tailIdx = frameCount - fadeSamples + k
      raw[k] = raw[k] * alpha + raw[tailIdx] * (1.0 - alpha)
    }

    guard let buf = AVAudioPCMBuffer(
      pcmFormat: monoFormat,
      frameCapacity: AVAudioFrameCount(frameCount - fadeSamples)
    ),
    let ptr = buf.floatChannelData?[0] else {
      return nil
    }
    let outCount = frameCount - fadeSamples
    buf.frameLength = AVAudioFrameCount(outCount)
    for i in 0..<outCount {
      ptr[i] = tanh(raw[i] * 0.72)
    }
    return buf
  }
}

