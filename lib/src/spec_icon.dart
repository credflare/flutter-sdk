import 'package:flutter/widgets.dart';
import 'spec.generated.dart';

Path parseSpecPath(String data) {
  final tokens = RegExp(
    r'[MLCZ]|-?\d*\.?\d+(?:e-?\d+)?',
  ).allMatches(data).map((m) => m[0]!).toList();
  final path = Path();
  var i = 0;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    switch (tokens[i++]) {
      case 'M':
        path.moveTo(next(), next());
      case 'L':
        path.lineTo(next(), next());
      case 'C':
        path.cubicTo(next(), next(), next(), next(), next(), next());
      case 'Z':
        path.close();
      default:
        throw FormatException('Unsupported path command', data, i - 1);
    }
  }
  return path;
}

class SpecIconPainter extends CustomPainter {
  final SpecIcon icon;
  final Color color;
  const SpecIconPainter(this.icon, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / icon.viewBox;
    canvas.save();
    canvas.translate(
      (size.width - icon.viewBox * scale) / 2,
      (size.height - icon.viewBox * scale) / 2,
    );
    canvas.scale(scale);
    for (final item in icon.paths) {
      final path = parseSpecPath(item.d);
      if (item.fill) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = color.withValues(alpha: color.a * item.fillOpacity),
        );
      }
      if (item.stroke) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = item.strokeWidth
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = color.withValues(alpha: color.a * item.strokeOpacity),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SpecIconPainter old) =>
      old.icon != icon || old.color != color;
}

class CredflareIcon extends StatelessWidget {
  final SpecIcon icon;
  final double size;
  final Color? color;
  final String? semanticLabel;
  const CredflareIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      size: Size.square(size),
      painter: SpecIconPainter(
        icon,
        color ??
            DefaultTextStyle.of(context).style.color ??
            const Color(0xFF000000),
      ),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: paint)
        : Semantics(label: semanticLabel, image: true, child: paint);
  }
}
