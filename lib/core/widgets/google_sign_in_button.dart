import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A premium, official-style Google Sign-In button built using a CustomPainter
/// for the Google "G" logo, styled to fit our premium dark monochromatic theme.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Connect Google Account',
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            splashColor: Colors.black.withValues(alpha: 0.08),
            highlightColor: Colors.black.withValues(alpha: 0.04),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 13,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Programmatically drawn Google logo
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CustomPaint(
                      painter: _GoogleLogoPainter(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate()
     .fadeIn(duration: 350.ms)
     .scale(
       duration: 350.ms,
       begin: const Offset(0.96, 0.96),
       curve: Curves.easeOutBack,
     );
  }
}

/// A CustomPainter that draws the official Google logo using precise 24x24
/// vector paths scaled dynamically to fit the painter's canvas.
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24.0;

    // Red Sector (Top)
    final Paint redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final Path redPath = Path()
      ..moveTo(12.0 * s, 5.04 * s)
      ..cubicTo(13.94 * s, 5.04 * s, 15.51 * s, 5.72 * s, 16.79 * s, 6.76 * s)
      ..lineTo(20.2 * s, 3.35 * s)
      ..cubicTo(18.17 * s, 1.57 * s, 15.35 * s, 0.5 * s, 12.0 * s, 0.5 * s)
      ..cubicTo(7.42 * s, 0.5 * s, 3.52 * s, 3.12 * s, 1.63 * s, 6.94 * s)
      ..lineTo(5.59 * s, 10.01 * s)
      ..cubicTo(6.52 * s, 7.02 * s, 9.0 * s, 5.04 * s, 12.0 * s, 5.04 * s)
      ..close();
    canvas.drawPath(redPath, redPaint);

    // Yellow Sector (Left)
    final Paint yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final Path yellowPath = Path()
      ..moveTo(5.59 * s, 10.01 * s)
      ..cubicTo(5.35 * s, 9.29 * s, 5.21 * s, 8.51 * s, 5.21 * s, 7.7 * s)
      ..cubicTo(5.21 * s, 6.89 * s, 5.35 * s, 6.11 * s, 5.59 * s, 5.39 * s)
      ..lineTo(1.63 * s, 5.39 * s)
      ..cubicTo(0.59 * s, 7.52 * s, 0.0, 9.92 * s, 0.0, 12.45 * s)
      ..cubicTo(0.0, 14.98 * s, 0.59 * s, 17.38 * s, 1.63 * s, 19.51 * s)
      ..lineTo(5.59 * s, 16.46 * s)
      ..cubicTo(5.35 * s, 15.74 * s, 5.21 * s, 14.96 * s, 5.21 * s, 14.15 * s)
      ..cubicTo(5.21 * s, 13.34 * s, 5.35 * s, 12.56 * s, 5.59 * s, 11.84 * s)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Green Sector (Bottom)
    final Paint greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final Path greenPath = Path()
      ..moveTo(12.0 * s, 23.5 * s)
      ..cubicTo(15.24 * s, 23.5 * s, 18.06 * s, 22.43 * s, 20.08 * s, 20.59 * s)
      ..lineTo(16.25 * s, 17.62 * s)
      ..cubicTo(15.14 * s, 18.37 * s, 13.72 * s, 18.82 * s, 12.0 * s, 18.82 * s)
      ..cubicTo(9.0 * s, 18.82 * s, 6.52 * s, 16.84 * s, 5.59 * s, 13.85 * s)
      ..lineTo(1.63 * s, 16.92 * s)
      ..cubicTo(3.52 * s, 20.78 * s, 7.42 * s, 23.5 * s, 12.0 * s, 23.5 * s)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Blue Sector (Right)
    final Paint bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final Path bluePath = Path()
      ..moveTo(23.5 * s, 12.0 * s)
      ..cubicTo(23.5 * s, 11.18 * s, 23.43 * s, 10.4 * s, 23.29 * s, 9.64 * s)
      ..lineTo(12.0 * s, 9.64 * s)
      ..lineTo(12.0 * s, 14.15 * s)
      ..lineTo(18.47 * s, 14.15 * s)
      ..cubicTo(18.19 * s, 15.63 * s, 17.35 * s, 16.89 * s, 16.09 * s, 17.73 * s)
      ..lineTo(19.92 * s, 20.7 * s)
      ..cubicTo(22.16 * s, 18.63 * s, 23.5 * s, 15.59 * s, 23.5 * s, 12.0 * s)
      ..close();
    canvas.drawPath(bluePath, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
