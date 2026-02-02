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
        child: Opacity(
          opacity: isScanning ? 1.0 : 0.3,
          child: CameraPreview(cameraController!),
        ),
      );
    } else {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.softWhite,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isCameraPermissionDenied) ...[
              Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: AppColors.grayText,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera Permission Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please grant camera access to scan medications',
                style: TextStyle(fontSize: 14, color: AppColors.grayText),
                textAlign: TextAlign.center,
              ),
            ] else if (errorMessage != null) ...[
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  errorMessage!,
                  style: TextStyle(fontSize: 14, color: AppColors.grayText),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              const CircularProgressIndicator(color: AppColors.primaryTeal),
              const SizedBox(height: 16),
              Text(
                'Initializing camera...',
                style: TextStyle(fontSize: 14, color: AppColors.grayText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom controls for scanning state
/// Shows capture button and manual add option
class ScanBottomControls extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onCapture;
  final VoidCallback onManualAdd;

  const ScanBottomControls({
    super.key,
    required this.isProcessing,
    required this.onCapture,
    required this.onManualAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.black.withValues(alpha: 0.4),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              GestureDetector(
                onTap: isProcessing ? null : onCapture,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryTeal, AppColors.deepTeal],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryTeal.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    isProcessing
                        ? Icons.hourglass_empty
                        : Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tap to capture or wait for auto-scan',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onManualAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Can't Scan? Add Manually",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
