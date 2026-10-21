import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'dice_geometry.dart';

/// Um dado 3D que rola: gira solto, perde velocidade, quica e para com a face
/// sorteada virada para quem olha. Desenhado à mão (faces com luz e sombra e
/// os números no plano de cada face).
class RollingDie extends StatefulWidget {
  final DieKind kind;
  final Color color;

  /// Chamado quando o dado para (com o valor da face de cima).
  final ValueChanged<int>? onLanded;

  const RollingDie({super.key, required this.kind, required this.color, this.onLanded});

  @override
  State<RollingDie> createState() => RollingDieState();
}

class RollingDieState extends State<RollingDie> with SingleTickerProviderStateMixin {
  final _random = Random();
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..addStatusListener(_onStatus);

  late DieShape _shape = DieShape.of(widget.kind);
  late Quat _start = _restingQuat(_shape.faces.map((f) => f.value).reduce(max));
  late Quat _end = _start;
  V3 _axis = const V3(1, 1, 0);
  double _spin = 0;
  int? _value;

  bool get rolling => _controller.isAnimating;

  // O D4 de frente parece um triângulo: inclina mais para ver a pirâmide.
  Quat _restingQuat(int value) => Quat.fromMatrix(
      _shape.kind == DieKind.d4 ? _shape.restingOn(value, tiltX: 0.62, tiltY: -0.42) : _shape.restingOn(value));

  @override
  void didUpdateWidget(RollingDie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) {
      _controller.stop();
      _shape = DieShape.of(widget.kind);
      _start = _end = _restingQuat(_shape.faces.map((f) => f.value).reduce(max));
      _value = null;
    }
  }

  /// Rola até parar em [value] (sorteado por quem chama).
  void roll(int value) {
    _start = _current;
    _end = _restingQuat(value);
    _value = value;
    _axis = V3(_random.nextDouble() * 2 - 1, _random.nextDouble() * 2 - 1, _random.nextDouble() - 0.5).unit;
    _spin = 2 * pi * (2.5 + _random.nextDouble() * 1.5);
    _controller.forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _value != null) widget.onLanded?.call(_value!);
  }

  double get _eased => Curves.easeOutCubic.transform(_controller.value);

  Quat get _current {
    final e = _eased;
    // Gira em volta de um eixo sorteado, cada vez mais devagar, enquanto vai
    // da posição antiga para a final (no fim, o giro extra é zero).
    return Quat.axisAngle(_axis, (1 - e) * _spin) * _start.slerp(_end, e);
  }

  /// Altura dos quiques (0 = no chão).
  double get _lift {
    final t = _controller.value;
    if (t >= 1) return 0;
    return (sin(t * pi * 3.2)).abs() * pow(1 - t, 1.6).toDouble();
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
      builder: (context, _) => CustomPaint(
        painter: _DiePainter(shape: _shape, rotation: _current.toMatrix(), color: widget.color, lift: _lift),
        size: Size.infinite,
      ),
    );
  }
}

class _DiePainter extends CustomPainter {
  final DieShape shape;
  final M3 rotation;
  final Color color;
  final double lift;

  _DiePainter({required this.shape, required this.rotation, required this.color, required this.lift});

  static const _camera = 5.0; // distância da câmera (perspectiva)
  static final _light = const V3(-0.45, 0.65, 0.75).unit;
  static final Map<String, TextPainter> _labels = {};

  static TextPainter _label(String text) => _labels[text] ??= (TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 100,
            fontWeight: FontWeight.w900,
            height: 1,
            shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout());

  @override
  void paint(Canvas canvas, Size size) {
    // O maior tamanho que cabe (o D100 divide a largura em dois dados).
    final scale = min(size.width * 0.40, size.height * 0.36);
    final cx = size.width / 2;
    final ground = size.height / 2 + scale * 0.15;
    final cy = ground - lift * size.height * 0.22;

    Offset project(V3 p) {
      final k = _camera / (_camera - p.z);
      return Offset(cx + p.x * scale * k, cy - p.y * scale * k);
    }

    // Sombra no chão: menor e mais clara quando o dado está no alto.
    final shadowW = scale * (1.9 - lift * 0.6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, ground + scale * 1.05), width: shadowW, height: shadowW * 0.22),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45 - lift * 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final verts = [for (final v in shape.vertices) rotation.apply(v)];
    final eye = const V3(0, 0, _camera);
    final visible = <(DieFace, V3, V3)>[];
    for (final f in shape.faces) {
      final n = rotation.apply(f.normal), c = rotation.apply(f.center);
      if (n.dot(eye - c) > 0) visible.add((f, n, c));
    }
    visible.sort((a, b) => a.$3.z.compareTo(b.$3.z)); // de trás para frente

    final hsl = HSLColor.fromColor(color);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, scale * 0.012)
      ..strokeJoin = StrokeJoin.round
      ..color = hsl.withLightness((hsl.lightness * 0.45).clamp(0, 1)).toColor();

    for (final (f, n, c) in visible) {
      // Luz: mais clara a face virada para a luz, com um brilho suave.
      final diffuse = max(0.0, n.dot(_light));
      final shade = 0.42 + 0.58 * diffuse;
      final specular = pow(max(0.0, n.dot((_light + const V3(0, 0, 1)).unit)), 24).toDouble();
      final base = hsl.withLightness((hsl.lightness * shade + specular * 0.25).clamp(0, 0.92)).toColor();

      final path = Path();
      for (int i = 0; i < f.corners.length; i++) {
        final p = project(verts[f.corners[i]]);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = base);
      canvas.drawPath(path, edge);

      // O número no plano da face: os eixos da face (direita e cima) viram
      // eixos na tela, então o número entorta junto com a face.
      final facing = n.dot((eye - c).unit);
      if (facing < 0.12) continue;
      final up = rotation.apply(f.up), right = rotation.apply(f.up.cross(f.normal));
      const e = 0.02;
      final origin = project(c);
      final ex = (project(c + right * e) - origin) / e;
      final ey = (project(c - up * e) - origin) / e;
      final label = _label(f.label);
      final digits = f.label.replaceAll('.', '').length;
      final letter = f.inradius * (digits == 1 ? 1.15 : digits == 2 ? 0.9 : 0.72);
      final k = letter / 100;
      canvas.save();
      canvas.transform(Float64List.fromList([
        ex.dx * k, ex.dy * k, 0, 0, //
        ey.dx * k, ey.dy * k, 0, 0, //
        0, 0, 1, 0, //
        origin.dx, origin.dy, 0, 1,
      ]));
      final fade = ((facing - 0.12) / 0.3).clamp(0.0, 1.0);
      if (fade < 1) {
        canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: fade));
        label.paint(canvas, Offset(-label.width / 2, -label.height / 2));
        canvas.restore();
      } else {
        label.paint(canvas, Offset(-label.width / 2, -label.height / 2));
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DiePainter old) => old.rotation != rotation || old.lift != lift || old.color != color || old.shape != shape;
}
