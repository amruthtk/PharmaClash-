/// Scan Screen Module
///
/// This module provides medication scanning functionality with:
/// - Camera-based OCR scanning
/// - Manual drug search
/// - Drug verification and warnings
/// - Results display with risk assessment
///
/// The module is organized into:
/// - scan_screen.dart (main coordinator)
/// - widgets/ (UI components)
/// - utils/ (OCR processing)

library;

export 'scan_screen.dart';
export 'widgets/camera_viewfinder.dart';
export 'widgets/drug_search_field.dart';
export 'widgets/verification_overlay.dart';
export 'widgets/results_overlay.dart';
export 'utils/ocr_processor.dart';
