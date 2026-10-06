import 'package:flutter/material.dart';

import '../constants.dart';
import '../theme/tokens.dart';

/// Brand mark painted from the handoff SVG (32-unit box). Exposed to screen
/// readers as [appName] since it is the brand identity, not decoration.
class RelayLogo extends StatelessWidget {
  const RelayLogo({super.key, this.size = 44, this.inverted = false});

  final double size;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: appName,
      image: true,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: _LogoPainter(inverted),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.inverted);
  final bool inverted;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 32;
    canvas.scale(s);
    final tile = inverted ? RelayColors.surface : RelayColors.ink;
    final mark = inverted ? RelayColors.ink : RelayColors.surface;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 32, 32),
        const Radius.circular(9),
      ),
      Paint()..color = tile,
    );
    final stroke = Paint()
      ..color = mark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(9.5, 12)
        ..lineTo(22.5, 12)
        ..moveTo(9.5, 17)
        ..lineTo(17.5, 17),
      stroke,
    );
    canvas.drawCircle(
      const Offset(22, 21),
      2.6,
      Paint()..color = RelayColors.accent,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.inverted != inverted;
}
