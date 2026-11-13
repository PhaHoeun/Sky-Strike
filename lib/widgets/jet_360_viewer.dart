import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../models/game_models.dart';
import '../theme/avionics_theme.dart';

/// Shared aircraft livery colors used by both the Hangar camo UI
/// and the 2D Dogfight Canvas renderer.
class JetCamoStyle {
  const JetCamoStyle({
    required this.upper,
    required this.mid,
    required this.lower,
    required this.trim,
    required this.canopyTop,
    required this.canopyBottom,
    required this.afterburnerOuter,
    required this.afterburnerCore,
  });

  final Color upper;
  final Color mid;
  final Color lower;
  final Color trim;
  final Color canopyTop;
  final Color canopyBottom;
  final Color afterburnerOuter;
  final Color afterburnerCore;
}

/// Resolves deterministic livery palette for any aircraft camo preset.
JetCamoStyle resolveJetCamoStyle(String camoName, Color jetAccent) {
  return switch (camoName) {
    'ARCTIC GHOST' => const JetCamoStyle(
      upper: Color(0xFFDCE7F2),
      mid: Color(0xFF8FA7BD),
      lower: Color(0xFF43566B),
      trim: Color(0xFF00E5FF),
      canopyTop: Color(0xFF285578),
      canopyBottom: Color(0xFF7BE8FF),
      afterburnerOuter: Color(0xFF00D8FF),
      afterburnerCore: Color(0xFFE9FCFF),
    ),
    'APEX ORANGE' => const JetCamoStyle(
      upper: Color(0xFF474E5B),
      mid: Color(0xFF2D333E),
      lower: Color(0xFF1A1F27),
      trim: Color(0xFFFE6B00),
      canopyTop: Color(0xFF6B3A18),
      canopyBottom: Color(0xFFFFB24A),
      afterburnerOuter: Color(0xFFFE6B00),
      afterburnerCore: Color(0xFFFFF3CC),
    ),
    'NIGHTHAWK' => JetCamoStyle(
      upper: const Color(0xFF232C3C),
      mid: const Color(0xFF151C27),
      lower: const Color(0xFF0B1018),
      trim: jetAccent,
      canopyTop: const Color(0xFF182A40),
      canopyBottom: const Color(0xFF3FD8FF),
      afterburnerOuter: const Color(0xFF38BDF8),
      afterburnerCore: const Color(0xFFE6FAFF),
    ),
    'OBSIDIAN NAVY' => const JetCamoStyle(
      upper: Color(0xFF334761),
      mid: Color(0xFF203046),
      lower: Color(0xFF121C2B),
      trim: Color(0xFF00DAF3),
      canopyTop: Color(0xFF1A435B),
      canopyBottom: Color(0xFF6AEBFF),
      afterburnerOuter: Color(0xFF00E5FF),
      afterburnerCore: Color(0xFFE7FCFF),
    ),
    'DIGITAL FLANKER' => const JetCamoStyle(
      upper: Color(0xFF7C92A8),
      mid: Color(0xFF4C6075),
      lower: Color(0xFF263342),
      trim: Color(0xFFFE6B00),
      canopyTop: Color(0xFF3D3428),
      canopyBottom: Color(0xFFFFC168),
      afterburnerOuter: Color(0xFFFE6B00),
      afterburnerCore: Color(0xFFFFF2CF),
    ),
    'EXPERIMENTAL TITANIUM' => const JetCamoStyle(
      upper: Color(0xFF8C97A6),
      mid: Color(0xFF535D6C),
      lower: Color(0xFF262D38),
      trim: Color(0xFFFFB800),
      canopyTop: Color(0xFF284F64),
      canopyBottom: Color(0xFF7BF2FF),
      afterburnerOuter: Color(0xFFFFB800),
      afterburnerCore: Color(0xFFFFF7D9),
    ),
    _ => JetCamoStyle(
      // STEALTH SLATE default
      upper: const Color(0xFF6B7D92),
      mid: const Color(0xFF404E60),
      lower: const Color(0xFF202A37),
      trim: jetAccent,
      canopyTop: const Color(0xFF24455E),
      canopyBottom: const Color(0xFF64E2FF),
      afterburnerOuter: const Color(0xFFFE7A1A),
      afterburnerCore: const Color(0xFFFFF4D2),
    ),
  };
}

class _JetKeyframeSpec {
  const _JetKeyframeSpec(this.assetPath, {this.flipX = false});

  final String assetPath;
  final bool flipX;
}

/// Maps each playable jet to 8 clockwise 45-degree turntable keyframes (0..315 deg),
/// ensuring consistent nose direction from front-left (45) through rear (180) and right (270).
List<_JetKeyframeSpec> _resolveJetKeyframes(String jetId) {
  switch (jetId) {
    case 'f35':
      return const [
        _JetKeyframeSpec('assets/images/jets/f35_000.png'),
        _JetKeyframeSpec('assets/images/jets/f35_045.png'),
        _JetKeyframeSpec('assets/images/jets/f35_090.png', flipX: true),
        _JetKeyframeSpec('assets/images/jets/f35_135.png', flipX: true),
        _JetKeyframeSpec('assets/images/jets/f35_180.png'),
        _JetKeyframeSpec('assets/images/jets/f35_135.png'),
        _JetKeyframeSpec('assets/images/jets/f35_090.png'),
        _JetKeyframeSpec('assets/images/jets/f35_045.png', flipX: true),
      ];
    case 'su57':
      return const [
        _JetKeyframeSpec('assets/images/jets/su57_000.png'),
        _JetKeyframeSpec('assets/images/jets/su57_045.png'),
        _JetKeyframeSpec('assets/images/jets/su57_090.png'),
        _JetKeyframeSpec('assets/images/jets/su57_135.png', flipX: true),
        _JetKeyframeSpec('assets/images/jets/su57_180.png'),
        _JetKeyframeSpec('assets/images/jets/su57_135.png'),
        _JetKeyframeSpec('assets/images/jets/su57_090.png', flipX: true),
        _JetKeyframeSpec('assets/images/jets/su57_045.png', flipX: true),
      ];
    case 'x02':
      return const [
        _JetKeyframeSpec('assets/images/jets/x02_000.png'),
        _JetKeyframeSpec('assets/images/jets/x02_045.png'),
        _JetKeyframeSpec('assets/images/jets/x02_090.png'),
        _JetKeyframeSpec('assets/images/jets/x02_135.png'),
        _JetKeyframeSpec('assets/images/jets/x02_180.png'),
        _JetKeyframeSpec('assets/images/jets/x02_135.png', flipX: true),
        _JetKeyframeSpec('assets/images/jets/x02_090.png', flipX: true),
        _JetKeyframeSpec('assets/images/jets/x02_045.png', flipX: true),
      ];
    case 'f22':
    default:
      return const [
        _JetKeyframeSpec('assets/images/jets/f22_000.png'),
        _JetKeyframeSpec('assets/images/jets/f22_045.png'),
        _JetKeyframeSpec('assets/images/jets/f22_090.png', flipX: true),
        _JetKeyframeSpec('assets/images/jets/f22_135.png', flipX: true),
        _JetKeyframeSpec('assets/images/jets/f22_180.png'),
        _JetKeyframeSpec('assets/images/jets/f22_135.png'),
        _JetKeyframeSpec('assets/images/jets/f22_090.png'),
        _JetKeyframeSpec('assets/images/jets/f22_045.png', flipX: true),
      ];
  }
}

/// Interactive photorealistic 360-degree Hangar showcase for each playable jet.
/// Supports touch drag orbit (yaw 0-360 deg & pitch tilt), double-tap reset,
/// and continuous turntable rotation when [autoSpin] is active.
class Jet360Viewer extends StatefulWidget {
  const Jet360Viewer({
    super.key,
    required this.jet,
    required this.autoSpin,
    this.onOrientationChanged,
  });

  final JetConfig jet;
  final bool autoSpin;
  final void Function(int headingDeg, int pitchDeg)? onOrientationChanged;

  @override
  State<Jet360Viewer> createState() => _Jet360ViewerState();
}

class _Jet360ViewerState extends State<Jet360Viewer>
    with SingleTickerProviderStateMixin {
  // Starts right on the 45-degree hero 3/4 studio view.
  static const double _defaultYaw = math.pi / 4.0;
  static const double _defaultPitch = 0.25;
  static const String _platformViewType = 'com.fightingjet/jet_3d_view';

  late final AnimationController _ticker;
  double _yaw = _defaultYaw;
  double _pitch = _defaultPitch;
  double _yawVelocity = 0.0;
  double _lastTick = 0.0;
  bool _dragging = false;
  String? _precacheJetId;
  MethodChannel? _nativeChannel;
  int? _lastReportedYawDeg;
  int? _lastReportedPitchDeg;

  bool get _useNative3dView {
    if (kIsWeb) return false;
    final isApple = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (!isApple) return false;
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return !bindingName.contains('TestWidgetsFlutterBinding');
  }

  double get _yawDeg {
    var deg = (_yaw * 180.0 / math.pi) % 360.0;
    if (deg < 0) deg += 360.0;
    return deg;
  }

  double get _nativePitchDeg => (_pitch - _defaultPitch) * 180.0 / math.pi;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..addListener(_onFrameTick);
    if (widget.autoSpin) {
      _ticker.repeat();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyOrientation());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheActiveJetFrames();
  }

  @override
  void didUpdateWidget(covariant Jet360Viewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoSpin != widget.autoSpin) {
      if (widget.autoSpin || _yawVelocity.abs() > 0.05) {
        _ensureTickerRunning();
      } else {
        _ticker.stop();
      }
    }
    if (oldWidget.jet.id != widget.jet.id) {
      _precacheActiveJetFrames();
      _syncJetNative();
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyOrientation());
    } else if (oldWidget.jet.selectedCamo != widget.jet.selectedCamo ||
        oldWidget.jet.unlocked != widget.jet.unlocked ||
        oldWidget.jet.accentColorValue != widget.jet.accentColorValue) {
      _syncCamoNative();
    }
  }

  void _ensureTickerRunning() {
    if (!_ticker.isAnimating) {
      _lastTick = _ticker.value;
      _ticker.repeat();
    }
  }

  void _precacheActiveJetFrames() {
    if (_useNative3dView || _precacheJetId == widget.jet.id) return;
    _precacheJetId = widget.jet.id;
    final uniquePaths = _resolveJetKeyframes(
      widget.jet.id,
    ).map((k) => k.assetPath).toSet();
    for (final path in uniquePaths) {
      precacheImage(AssetImage(path), context).catchError((_) {});
    }
  }

  void _onFrameTick() {
    final now = _ticker.value;
    var delta = now - _lastTick;
    if (delta < 0) delta += 1.0;
    _lastTick = now;

    // Ticker duration is 12 seconds -> convert normalized delta to seconds.
    final dtSec = delta * 12.0;
    bool rotated = false;

    if (!_dragging) {
      if (_yawVelocity.abs() > 0.04) {
        _yaw = (_yaw + _yawVelocity * dtSec) % (2 * math.pi);
        if (_yaw < 0) _yaw += 2 * math.pi;
        _yawVelocity *= math.exp(-3.6 * dtSec);
        rotated = true;
      } else {
        _yawVelocity = 0.0;
        if (!widget.autoSpin && _ticker.isAnimating) {
          _ticker.stop();
        }
      }

      if (widget.autoSpin) {
        // Full 360 deg orbit roughly every 7.5 seconds when auto-inspecting.
        _yaw = (_yaw + delta * (2 * math.pi * (12.0 / 7.5))) % (2 * math.pi);
        rotated = true;
      }
    }

    if (rotated) {
      if (_useNative3dView) {
        _syncOrientationNative();
      }
      _notifyOrientation();
    }

    if (mounted && !_useNative3dView) {
      setState(() {});
    }
  }

  void _notifyOrientation() {
    final cb = widget.onOrientationChanged;
    if (cb == null) return;
    var deg = (_yaw * 180.0 / math.pi).round() % 360;
    if (deg < 0) deg += 360;
    final pitchDeg = (_pitch * 180.0 / math.pi).round();
    if (deg == _lastReportedYawDeg && pitchDeg == _lastReportedPitchDeg) {
      return;
    }
    _lastReportedYawDeg = deg;
    _lastReportedPitchDeg = pitchDeg;
    cb(deg, pitchDeg);
  }

  Map<String, dynamic> _buildNativePayload() {
    final camoStyle = resolveJetCamoStyle(
      widget.jet.selectedCamo,
      widget.jet.accentColor,
    );
    return <String, dynamic>{
      'jetId': widget.jet.id,
      'camo': widget.jet.selectedCamo,
      'unlocked': widget.jet.unlocked,
      'trimArgb': camoStyle.trim.toARGB32(),
      'canopyArgb': camoStyle.canopyTop.toARGB32(),
      'afterburnerArgb': camoStyle.afterburnerOuter.toARGB32(),
      'yawDeg': _yawDeg,
      'pitchDeg': _nativePitchDeg,
    };
  }

  void _syncOrientationNative() {
    _nativeChannel?.invokeMethod<void>('setOrientation', <String, dynamic>{
      'yawDeg': _yawDeg,
      'pitchDeg': _nativePitchDeg,
    });
  }

  void _syncJetNative() {
    if (!_useNative3dView) return;
    _nativeChannel?.invokeMethod<void>('setJet', _buildNativePayload());
  }

  void _syncCamoNative() {
    if (!_useNative3dView) return;
    final payload = _buildNativePayload();
    _nativeChannel?.invokeMethod<void>('setCamo', <String, dynamic>{
      'camo': payload['camo'],
      'unlocked': payload['unlocked'],
      'trimArgb': payload['trimArgb'],
      'canopyArgb': payload['canopyArgb'],
      'afterburnerArgb': payload['afterburnerArgb'],
    });
  }

  void _handlePanStart(DragStartDetails _) {
    _dragging = true;
    _yawVelocity = 0.0;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    _yaw = (_yaw - details.delta.dx * 0.014) % (2 * math.pi);
    if (_yaw < 0) _yaw += 2 * math.pi;
    _pitch = (_pitch + details.delta.dy * 0.009).clamp(-0.20, 0.56);

    if (_useNative3dView) {
      _syncOrientationNative();
    } else if (mounted) {
      setState(() {});
    }
    _notifyOrientation();
  }

  void _handlePanEnd(DragEndDetails details) {
    _dragging = false;
    final vx = details.velocity.pixelsPerSecond.dx;
    _yawVelocity = (-vx * 0.0125).clamp(-14.0, 14.0);
    if (_yawVelocity.abs() > 0.08 || widget.autoSpin) {
      _ensureTickerRunning();
    }
  }

  void _resetCamera() {
    _yawVelocity = 0.0;
    _yaw = _defaultYaw;
    _pitch = _defaultPitch;
    if (_useNative3dView) {
      _syncOrientationNative();
    } else if (mounted) {
      setState(() {});
    }
    _notifyOrientation();
  }

  @override
  void dispose() {
    _ticker.removeListener(_onFrameTick);
    _ticker.dispose();
    super.dispose();
  }

  Widget _buildNativeSceneView() {
    final creationParams = _buildNativePayload();
    void onCreated(int id) {
      _nativeChannel = MethodChannel('com.fightingjet/jet3d_$id');
      _syncOrientationNative();
      _syncJetNative();
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return IgnorePointer(
        child: UiKitView(
          viewType: _platformViewType,
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: onCreated,
        ),
      );
    }

    return IgnorePointer(
      child: AppKitView(
        viewType: _platformViewType,
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: onCreated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pulse = widget.autoSpin
        ? 0.5 + 0.5 * math.sin(_ticker.value * math.pi * 24)
        : 0.72;
    final useNative3d = _useNative3dView;

    return GestureDetector(
      key: const Key('jet_360_gesture_area'),
      behavior: HitTestBehavior.opaque,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onDoubleTap: _resetCamera,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _HangarTurntableBackdropPainter(
              jet: widget.jet,
              yaw: _yaw,
              pitch: _pitch,
              pulse: pulse,
              lockedPreview: !widget.jet.unlocked,
              show2dPedestal: !useNative3d,
            ),
          ),
          if (useNative3d)
            _buildNativeSceneView()
          else
            _buildFallbackTurntableOverlay(),
        ],
      ),
    );
  }

  Widget _buildFallbackTurntableOverlay() {
    final frames = _resolveJetKeyframes(widget.jet.id);
    final exactIdx = ((_yaw * 180.0 / math.pi) / 45.0) % 8.0;
    final positiveIdx = exactIdx < 0 ? exactIdx + 8.0 : exactIdx;
    final idx0 = positiveIdx.floor() % 8;
    final idx1 = (idx0 + 1) % 8;
    final t = positiveIdx - positiveIdx.floor();
    final smoothT = t * t * (3.0 - 2.0 * t);

    final tiltPitch = (_pitch - _defaultPitch) * 0.55;
    const maxStepPerspective = 0.22;
    final camoFilter = resolveCamoColorFilter(widget.jet);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 26),
      child: ColorFiltered(
        colorFilter: camoFilter,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPerspectiveFrame(
              spec: frames[idx0],
              opacity: 1.0 - smoothT * 0.65,
              yawDeltaRad: -t * maxStepPerspective,
              pitchRad: tiltPitch,
              unlocked: widget.jet.unlocked,
            ),
            if (smoothT > 0.005)
              _buildPerspectiveFrame(
                spec: frames[idx1],
                opacity: smoothT,
                yawDeltaRad: (1.0 - t) * maxStepPerspective,
                pitchRad: tiltPitch,
                unlocked: widget.jet.unlocked,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerspectiveFrame({
    required _JetKeyframeSpec spec,
    required double opacity,
    required double yawDeltaRad,
    required double pitchRad,
    required bool unlocked,
  }) {
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(-pitchRad)
      ..rotateY(yawDeltaRad);
    if (spec.flipX) {
      matrix.multiply(Matrix4.diagonal3Values(-1.0, 1.0, 1.0));
    }

    return Opacity(
      opacity: (opacity * (unlocked ? 1.0 : 0.88)).clamp(0.0, 1.0),
      child: Transform(
        alignment: Alignment.center,
        transform: matrix,
        child: Image.asset(
          spec.assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

/// Resolves a GPU color matrix matching any jet's livery preset and unlock tint.
ColorFilter resolveCamoColorFilter(JetConfig jet) {
  if (!jet.unlocked) {
    return const ColorFilter.matrix([
      0.84, 0.08, 0.08, 0, 6, //
      0.06, 0.88, 0.08, 0, 10, //
      0.06, 0.10, 0.94, 0, 16, //
      0, 0, 0, 1, 0,
    ]);
  }
  final camo = jet.selectedCamo;
  final nativeCamo = switch (jet.id) {
    'f35' => 'OBSIDIAN NAVY',
    'su57' => 'DIGITAL FLANKER',
    'x02' => 'EXPERIMENTAL TITANIUM',
    _ => 'STEALTH SLATE',
  };
  // Preserve native factory liveries untouched for peak photoreal clarity.
  if (camo == nativeCamo) {
    return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
  }
  return switch (camo) {
    'ARCTIC GHOST' => const ColorFilter.matrix([
      1.18, 0.10, 0.10, 0, 24, //
      0.08, 1.22, 0.12, 0, 28, //
      0.08, 0.12, 1.28, 0, 34, //
      0, 0, 0, 1, 0,
    ]),
    'APEX ORANGE' => const ColorFilter.matrix([
      1.16, 0.18, 0.0, 0, 16, //
      0.06, 0.92, 0.0, 0, 2, //
      0.0, 0.02, 0.72, 0, -10, //
      0, 0, 0, 1, 0,
    ]),
    'NIGHTHAWK' => const ColorFilter.matrix([
      0.72, 0.0, 0.04, 0, -14, //
      0.0, 0.76, 0.06, 0, -10, //
      0.04, 0.08, 0.88, 0, -2, //
      0, 0, 0, 1, 0,
    ]),
    'OBSIDIAN NAVY' => const ColorFilter.matrix([
      0.86, 0.04, 0.08, 0, -6, //
      0.02, 0.96, 0.10, 0, 4, //
      0.06, 0.12, 1.18, 0, 16, //
      0, 0, 0, 1, 0,
    ]),
    'DIGITAL FLANKER' => const ColorFilter.matrix([
      1.04, 0.08, 0.04, 0, 8, //
      0.04, 1.08, 0.08, 0, 12, //
      0.06, 0.12, 1.16, 0, 16, //
      0, 0, 0, 1, 0,
    ]),
    'EXPERIMENTAL TITANIUM' => const ColorFilter.matrix([
      1.12, 0.08, 0.0, 0, 10, //
      0.06, 1.06, 0.02, 0, 6, //
      0.0, 0.04, 0.92, 0, -4, //
      0, 0, 0, 1, 0,
    ]),
    _ => const ColorFilter.mode(Colors.transparent, BlendMode.dst),
  };
}

class _HangarTurntableBackdropPainter extends CustomPainter {
  const _HangarTurntableBackdropPainter({
    required this.jet,
    required this.yaw,
    required this.pitch,
    required this.pulse,
    required this.lockedPreview,
    this.show2dPedestal = true,
  });

  final JetConfig jet;
  final double yaw;
  final double pitch;
  final double pulse;
  final bool lockedPreview;
  final bool show2dPedestal;

  @override
  void paint(Canvas canvas, Size size) {
    _paintHangarEnvironment(canvas, size);
    if (show2dPedestal) {
      _paintTurntableStage(canvas, size);
    }
  }

  void _paintHangarEnvironment(Canvas canvas, Size size) {
    final bgRect = Offset.zero & size;
    final horizonY = size.height * 0.66;

    // Illuminated tactical steel-blue hangar bay walls + brighter horizon separation for dark stealth jets
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.36, 0.65, 0.72, 1.0],
          colors: [
            Color(0xFF1A3246),
            Color(0xFF335E7B),
            Color(0xFF4A7E9E),
            Color(0xFF28465C),
            Color(0xFF162A39),
          ],
        ).createShader(bgRect),
    );

    // Bright overhead hangar skylight ceiling trusses & converging structural rafters
    final trussPaint = Paint()
      ..color = const Color(0xFF83B8D6).withValues(alpha: 0.28)
      ..strokeWidth = 1.25;
    for (int i = 0; i <= 6; i++) {
      final x = size.width * (i / 6.0);
      canvas.drawLine(
        Offset(x, 0),
        Offset(size.width * 0.5 + (x - size.width * 0.5) * 0.68, horizonY),
        trussPaint,
      );
    }

    // Back bulkhead wall horizontal gantry girders
    final girderPaint = Paint()
      ..color = const Color(0xFF8CC4E4).withValues(alpha: 0.22)
      ..strokeWidth = 1.1;
    for (final yFrac in [0.16, 0.34, 0.52]) {
      final y = size.height * yFrac;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), girderPaint);
    }

    // Recessed overhead hangar LED light panels centered cleanly between corner HUD readouts
    for (int i = -1; i <= 1; i++) {
      final panelCenterX = size.width * (0.5 + i * 0.115);
      final panelRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(panelCenterX, size.height * 0.12),
          width: size.width * 0.085,
          height: size.height * 0.028,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        panelRect,
        Paint()..color = const Color(0xFFD6F4FF).withValues(alpha: 0.44),
      );

      final beamPath = Path()
        ..moveTo(panelCenterX - size.width * 0.042, size.height * 0.135)
        ..lineTo(panelCenterX + size.width * 0.042, size.height * 0.135)
        ..lineTo(panelCenterX + size.width * 0.19, size.height * 0.86)
        ..lineTo(panelCenterX - size.width * 0.19, size.height * 0.86)
        ..close();
      canvas.drawPath(
        beamPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFB5ECFF).withValues(alpha: 0.22),
              const Color(0xFF7ACBF0).withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ).createShader(bgRect),
      );
    }

    // Crisp backlit halo directly behind the jet silhouette so dark liveries & panels pop cleanly
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.44),
        width: size.width * 0.84,
        height: size.height * 0.54,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF9EE4FF).withValues(alpha: 0.34),
            jet.accentColor.withValues(alpha: 0.18),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(bgRect),
    );

    // Lit hangar deck horizon band + perspective concrete apron lines
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      Paint()
        ..color = const Color(0xFFAADDF5).withValues(alpha: 0.42)
        ..strokeWidth = 1.4,
    );
    final floorGridPaint = Paint()
      ..color = const Color(0xFF6CAAD0).withValues(alpha: 0.24)
      ..strokeWidth = 1.0;
    for (int i = -4; i <= 4; i++) {
      canvas.drawLine(
        Offset(size.width * 0.5 + i * size.width * 0.09, horizonY),
        Offset(size.width * 0.5 + i * size.width * 0.22, size.height),
        floorGridPaint,
      );
    }

    // Bright floor spotlight pool under the turntable deck (cool cyan center + warm bay edge glow)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.81),
        width: size.width * 0.92,
        height: size.height * 0.36,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF7CD8FF).withValues(alpha: 0.28),
            AvionicsColors.orange.withValues(alpha: 0.14),
            Colors.transparent,
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(bgRect),
    );
  }

  void _paintTurntableStage(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.78);
    final rx = size.width * 0.41;
    final tiltSquash = (0.19 + pitch * 0.22).clamp(0.10, 0.34);
    final ry = rx * tiltSquash;

    // Dark recessed turntable pit ring
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2.15, height: ry * 2.25),
      Paint()..color = const Color(0xFF03080D).withValues(alpha: 0.72),
    );

    // Outer amber structural hex frame & inner cyan active ring rotating with yaw
    void drawHexRing(double scale, Color strokeColor, double width, double glow) {
      final path = Path();
      for (int i = 0; i < 6; i++) {
        final angle = yaw + i * math.pi / 3;
        final pt = Offset(
          center.dx + math.cos(angle) * rx * scale,
          center.dy + math.sin(angle) * ry * scale,
        );
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      if (glow > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..color = strokeColor.withValues(alpha: 0.32)
            ..style = PaintingStyle.stroke
            ..strokeWidth = glow
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }

    final rimColor = lockedPreview ? AvionicsColors.gold : jet.accentColor;
    drawHexRing(1.02, AvionicsColors.orange.withValues(alpha: 0.75), 1.6, 5.0);
    drawHexRing(0.86, rimColor.withValues(alpha: 0.55 + pulse * 0.25), 1.4, 4.0);

    // Compass azimuth degree ticks rotating seamlessly under the jet
    final tickPaint = Paint()
      ..color = rimColor.withValues(alpha: 0.38)
      ..strokeWidth = 1.1;
    for (int i = 0; i < 24; i++) {
      final a = yaw + (i * math.pi / 12.0);
      final innerScale = i % 2 == 0 ? 0.89 : 0.93;
      final outerScale = 0.97;
      canvas.drawLine(
        Offset(center.dx + math.cos(a) * rx * innerScale, center.dy + math.sin(a) * ry * innerScale),
        Offset(center.dx + math.cos(a) * rx * outerScale, center.dy + math.sin(a) * ry * outerScale),
        tickPaint,
      );
    }

    // Dynamic fuselage drop shadow oval responding subtly to aircraft yaw width
    final broadsideRatio = 0.55 + 0.45 * math.sin(yaw).abs();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - ry * 0.08),
        width: rx * 1.15 * broadsideRatio,
        height: ry * 0.85,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  @override
  bool shouldRepaint(covariant _HangarTurntableBackdropPainter oldDelegate) {
    if (oldDelegate.jet.id != jet.id ||
        oldDelegate.jet.selectedCamo != jet.selectedCamo ||
        oldDelegate.lockedPreview != lockedPreview ||
        oldDelegate.show2dPedestal != show2dPedestal) {
      return true;
    }
    if (!show2dPedestal) return false;
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.pulse != pulse;
  }
}
