import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../theme/app_colors.dart';

/// Camera viewfinder widget for the scan screen
/// Handles camera initialization, permission, and preview display
class CameraViewfinder extends StatelessWidget {
  final CameraController? cameraController;
  final bool isInitialized;
  final bool isCameraPermissionDenied;
  final String? errorMessage;
  final bool isScanning;

  const CameraViewfinder({
    super.key,
    required this.cameraController,
    required this.isInitialized,
    required this.isCameraPermissionDenied,
    this.errorMessage,
    this.isScanning = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isInitialized && cameraController != null) {
      return Positioned.fill(
        child: Stack(
          children: [
            AnimatedOpacity(
              opacity: isScanning ? 1.0 : 0.15,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: CameraPreview(cameraController!),
            ),
            if (isScanning) _buildScanningOverlay(context),
          ],
        ),
      );
    } else {
      return _buildPlaceholder();
    }
  }

  Widget _buildScanningOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanAreaWidth = size.width - 64;
    final scanAreaHeight = scanAreaWidth * 0.55;

    return Stack(
      children: [
        // Semi-transparent background with cut-out
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(color: Colors.transparent),
              ),
              Align(
                alignment: const Alignment(0, -0.1),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  width: scanAreaWidth,
                  height: scanAreaHeight,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Glowing scan frame
        Align(
          alignment: const Alignment(0, -0.1),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            width: scanAreaWidth,
            height: scanAreaHeight,
            child: Stack(
              children: [
                // Corner decorations
                _buildCorner(topLeft: true),
                _buildCorner(topRight: true),
                _buildCorner(bottomLeft: true),
                _buildCorner(bottomRight: true),

                // Animated scanning line
                const _ScanningLine(),
              ],
            ),
          ),
        ),

        // Instructions pill
        Positioned(
          top: MediaQuery.of(context).padding.top + 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.center_focus_weak_rounded,
                    color: AppColors.mintGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Align medicine label in frame',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorner({
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return Positioned(
      top: (topLeft || topRight) ? 0 : null,
      bottom: (bottomLeft || bottomRight) ? 0 : null,
      left: (topLeft || bottomLeft) ? 0 : null,
      right: (topRight || bottomRight) ? 0 : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border(
            top: (topLeft || topRight)
                ? BorderSide(color: AppColors.mintGreen, width: 3.5)
                : BorderSide.none,
            bottom: (bottomLeft || bottomRight)
                ? BorderSide(color: AppColors.mintGreen, width: 3.5)
                : BorderSide.none,
            left: (topLeft || bottomLeft)
                ? BorderSide(color: AppColors.mintGreen, width: 3.5)
                : BorderSide.none,
            right: (topRight || bottomRight)
                ? BorderSide(color: AppColors.mintGreen, width: 3.5)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isCameraPermissionDenied) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    size: 48,
                    color: AppColors.mintGreen,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Camera Permission Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please grant camera access to scan medications',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    errorMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: AppColors.mintGreen,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Initializing camera...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanningLine extends StatefulWidget {
  const _ScanningLine();

  @override
  State<_ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<_ScanningLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: _controller.value * (200 - 4),
          left: 8,
          right: 8,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mintGreen.withValues(alpha: 0.6),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
              gradient: LinearGradient(
                colors: [
                  AppColors.mintGreen.withValues(alpha: 0),
                  AppColors.mintGreen.withValues(alpha: 0.9),
                  AppColors.mintGreen,
                  AppColors.mintGreen.withValues(alpha: 0.9),
                  AppColors.mintGreen.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom controls for scanning state
/// Shows capture button, flashlight toggle, and manual add option
class ScanBottomControls extends StatelessWidget {
  final bool isProcessing;
  final bool isFlashOn;
  final VoidCallback onCapture;
  final VoidCallback onFlashToggle;
  final VoidCallback onManualAdd;

  const ScanBottomControls({
    super.key,
    required this.isProcessing,
    required this.isFlashOn,
    required this.onCapture,
    required this.onFlashToggle,
    required this.onManualAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.95),
              Colors.black.withValues(alpha: 0.7),
              Colors.black.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Action row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Manual Add Button (Left)
                  _buildActionButton(
                    icon: Icons.keyboard_rounded,
                    label: 'Type',
                    onTap: onManualAdd,
                    isActive: false,
                  ),

                  // Capture Button (Center)
                  GestureDetector(
                    onTap: isProcessing ? null : onCapture,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isProcessing
                              ? Colors.grey.shade600
                              : AppColors.mintGreen,
                          width: 3,
                        ),
                        boxShadow: isProcessing
                            ? []
                            : [
                                BoxShadow(
                                  color: AppColors.mintGreen.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isProcessing
                              ? Colors.grey.shade700
                              : Colors.white,
                        ),
                        child: Center(
                          child: isProcessing
                              ? SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.mintGreen,
                                  ),
                                )
                              : Icon(
                                  Icons.document_scanner_rounded,
                                  color: AppColors.deepTeal,
                                  size: 30,
                                ),
                        ),
                      ),
                    ),
                  ),

                  // Flashlight Button (Right)
                  _buildActionButton(
                    icon: isFlashOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    label: isFlashOn ? 'On' : 'Flash',
                    onTap: onFlashToggle,
                    isActive: isFlashOn,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Hint text
              Text(
                'Tap to scan · Type to search manually',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.mintGreen.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? AppColors.mintGreen.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? AppColors.mintGreen : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive
                  ? AppColors.mintGreen
                  : Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
