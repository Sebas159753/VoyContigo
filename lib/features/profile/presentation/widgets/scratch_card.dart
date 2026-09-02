import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:voycontigo/core/theme/app_theme.dart';

/// Tarjeta "raspa y gana": cubre a su [child] con una capa metalizada que el
/// usuario frota con el dedo. Al descubrir suficiente área (~45%) se revela
/// todo automáticamente y se dispara [onRevealed] una única vez.
class ScratchCard extends StatefulWidget {
  final Widget child;
  final double height;
  final List<Color> coverGradient;
  final String coverText;
  final BorderRadius borderRadius;
  final VoidCallback? onRevealed;

  const ScratchCard({
    super.key,
    required this.child,
    required this.height,
    required this.coverGradient,
    this.coverText = '✨ RASPA AQUÍ ✨',
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.onRevealed,
  });

  @override
  State<ScratchCard> createState() => _ScratchCardState();
}

class _ScratchCardState extends State<ScratchCard> {
  // Puntos raspados en coordenadas locales; null separa trazos.
  final List<Offset?> _points = [];

  // Rejilla para estimar el porcentaje descubierto.
  static const int _gridCols = 16;
  static const int _gridRows = 8;
  static const double _revealThreshold = 0.45;
  final Set<int> _scratchedCells = {};

  bool _revealed = false;

  void _addPoint(Offset localPosition, Size size) {
    if (_revealed) return;
    setState(() => _points.add(localPosition));
    _markCells(localPosition, size);
    final progress = _scratchedCells.length / (_gridCols * _gridRows);
    if (progress >= _revealThreshold) {
      _reveal();
    }
  }

  void _markCells(Offset p, Size size) {
    final col = (p.dx / size.width * _gridCols).floor();
    final row = (p.dy / size.height * _gridRows).floor();
    // El trazo es ancho: marcamos también las celdas vecinas.
    for (int dc = -1; dc <= 1; dc++) {
      for (int dr = -1; dr <= 1; dr++) {
        final c = col + dc;
        final r = row + dr;
        if (c >= 0 && c < _gridCols && r >= 0 && r < _gridRows) {
          _scratchedCells.add(r * _gridCols + c);
        }
      }
    }
  }

  void _reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
    widget.onRevealed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, widget.height);
            return Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                IgnorePointer(
                  ignoring: _revealed,
                  child: AnimatedOpacity(
                    opacity: _revealed ? 0 : 1,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOut,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) {
                        _points.add(null);
                        _addPoint(d.localPosition, size);
                      },
                      onPanUpdate: (d) => _addPoint(d.localPosition, size),
                      onPanEnd: (_) => _points.add(null),
                      child: CustomPaint(
                        painter: _ScratchCoverPainter(
                          points: List.of(_points),
                          gradientColors: widget.coverGradient,
                          coverText: widget.coverText,
                          textStyle: AppTheme.subtitleFont(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScratchCoverPainter extends CustomPainter {
  final List<Offset?> points;
  final List<Color> gradientColors;
  final String coverText;
  final TextStyle textStyle;

  _ScratchCoverPainter({
    required this.points,
    required this.gradientColors,
    required this.coverText,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());

    // Cubierta metalizada.
    final cover = Paint()
      ..shader = LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, cover);

    // Brillos decorativos tipo lotería.
    final sparkle = Paint()..color = Colors.white.withOpacity(0.12);
    final rng = math.Random(7); // semilla fija: mismo patrón en cada frame
    for (int i = 0; i < 26; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 3 + 1,
        sparkle,
      );
    }

    // Texto central "RASPA AQUÍ".
    final tp = TextPainter(
      text: TextSpan(text: coverText, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
    );

    // Borrado: los trazos del dedo "limpian" la cubierta.
    final clearStroke = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = 44
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final clearDot = Paint()..blendMode = BlendMode.clear;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      if (p == null) continue;
      canvas.drawCircle(p, 22, clearDot);
      if (i + 1 < points.length && points[i + 1] != null) {
        canvas.drawLine(p, points[i + 1]!, clearStroke);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScratchCoverPainter oldDelegate) =>
      oldDelegate.points.length != points.length;
}
