import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Official Google logo widget using SVG asset.
/// Use this across the app to maintain consistency.
class GoogleIcon extends StatelessWidget {
  final double size;

  const GoogleIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/google_logo.svg',
      width: size,
      height: size,
    );
  }
}
