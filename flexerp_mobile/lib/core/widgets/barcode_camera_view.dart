import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/flex_colors.dart';

/// Whether the device platform has camera barcode support (mobile_scanner).
bool get cameraScanSupported {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

/// Live camera barcode viewfinder backed by `mobile_scanner`.
///
/// [onDetected] fires once per distinct code (debounced) so a barcode held
/// in front of the camera does not add the product repeatedly.
class BarcodeCameraView extends StatefulWidget {
  final ValueChanged<String> onDetected;
  final double height;
  final Duration repeatDelay;

  const BarcodeCameraView({
    super.key,
    required this.onDetected,
    this.height = 220,
    this.repeatDelay = const Duration(milliseconds: 1500),
  });

  @override
  State<BarcodeCameraView> createState() => _BarcodeCameraViewState();
}

class _BarcodeCameraViewState extends State<BarcodeCameraView> {
  MobileScannerController? _controller;
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (cameraScanSupported) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handle(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      final now = DateTime.now();
      if (value == _lastCode && now.difference(_lastAt) < widget.repeatDelay) return;
      _lastCode = value;
      _lastAt = now;
      widget.onDetected(value);
      return;
    }
  }

  Widget _message(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white38, size: 36),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: FlexColors.primaryLight.withOpacity(0.6), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: controller == null
            ? _message(
                Icons.videocam_off_outlined,
                'Camera scanning is not available on this device.\n'
                'Use a USB / keyboard-wedge scanner or type the code below.',
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: controller,
                    onDetect: _handle,
                    errorBuilder: (context, error) {
                      final denied =
                          error.errorCode == MobileScannerErrorCode.permissionDenied;
                      return _message(
                        Icons.no_photography_outlined,
                        denied
                            ? 'Camera permission denied. Allow camera access in system '
                                'settings, or enter the barcode manually.'
                            : 'Camera unavailable (${error.errorCode.name}). '
                                'Enter the barcode manually.',
                      );
                    },
                  ),
                  IgnorePointer(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      color: FlexColors.danger.withOpacity(0.85),
                    ),
                  ),
                  const Positioned(
                    bottom: 8,
                    child: IgnorePointer(
                      child: Text(
                        'Point camera at 1D / 2D barcode',
                        style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      tooltip: 'Torch',
                      icon: const Icon(Icons.flashlight_on_outlined, color: Colors.white70),
                      onPressed: () => controller.toggleTorch(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
