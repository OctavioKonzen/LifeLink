import 'dart:math';

/// Vetor 3D simples (os dados são desenhados à mão, sem motor 3D).
class V3 {
  final double x, y, z;
  const V3(this.x, this.y, this.z);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double k) => V3(x * k, y * k, z * k);
  V3 operator -() => V3(-x, -y, -z);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => sqrt(dot(this));
  V3 get unit => this * (1 / length);

  @override
  String toString() => '(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Rotação 3x3 (linhas r0, r1, r2).
class M3 {
  final V3 r0, r1, r2;
  const M3(this.r0, this.r1, this.r2);
  static const identity = M3(V3(1, 0, 0), V3(0, 1, 0), V3(0, 0, 1));

  V3 apply(V3 v) => V3(r0.dot(v), r1.dot(v), r2.dot(v));

  M3 operator *(M3 o) {
    final c0 = V3(o.r0.x, o.r1.x, o.r2.x), c1 = V3(o.r0.y, o.r1.y, o.r2.y), c2 = V3(o.r0.z, o.r1.z, o.r2.z);
    return M3(V3(r0.dot(c0), r0.dot(c1), r0.dot(c2)), V3(r1.dot(c0), r1.dot(c1), r1.dot(c2)), V3(r2.dot(c0), r2.dot(c1), r2.dot(c2)));
  }

  static M3 axisAngle(V3 axis, double angle) => Quat.axisAngle(axis, angle).toMatrix();
}

/// Quatérnio, para girar o dado de forma suave entre duas posições.
class Quat {
  final double w, x, y, z;
  const Quat(this.w, this.x, this.y, this.z);

  factory Quat.axisAngle(V3 axis, double angle) {
    final a = axis.unit, s = sin(angle / 2);
    return Quat(cos(angle / 2), a.x * s, a.y * s, a.z * s);
  }

  /// Posição qualquer, sorteada de modo uniforme.
  factory Quat.random(Random r) {
    final u1 = r.nextDouble(), u2 = r.nextDouble() * 2 * pi, u3 = r.nextDouble() * 2 * pi;
    final a = sqrt(1 - u1), b = sqrt(u1);
    return Quat(a * sin(u2), a * cos(u2), b * sin(u3), b * cos(u3));
  }

  factory Quat.fromMatrix(M3 m) {
    final tr = m.r0.x + m.r1.y + m.r2.z;
    if (tr > 0) {
      final s = sqrt(tr + 1) * 2;
      return Quat(0.25 * s, (m.r2.y - m.r1.z) / s, (m.r0.z - m.r2.x) / s, (m.r1.x - m.r0.y) / s);
    } else if (m.r0.x > m.r1.y && m.r0.x > m.r2.z) {
      final s = sqrt(1 + m.r0.x - m.r1.y - m.r2.z) * 2;
      return Quat((m.r2.y - m.r1.z) / s, 0.25 * s, (m.r0.y + m.r1.x) / s, (m.r0.z + m.r2.x) / s);
    } else if (m.r1.y > m.r2.z) {
      final s = sqrt(1 + m.r1.y - m.r0.x - m.r2.z) * 2;
      return Quat((m.r0.z - m.r2.x) / s, (m.r0.y + m.r1.x) / s, 0.25 * s, (m.r1.z + m.r2.y) / s);
    } else {
      final s = sqrt(1 + m.r2.z - m.r0.x - m.r1.y) * 2;
      return Quat((m.r1.x - m.r0.y) / s, (m.r0.z + m.r2.x) / s, (m.r1.z + m.r2.y) / s, 0.25 * s);
    }
  }

  Quat operator *(Quat o) => Quat(
        w * o.w - x * o.x - y * o.y - z * o.z,
        w * o.x + x * o.w + y * o.z - z * o.y,
        w * o.y - x * o.z + y * o.w + z * o.x,
        w * o.z + x * o.y - y * o.x + z * o.w,
      );

  Quat slerp(Quat o, double t) {
    var d = w * o.w + x * o.x + y * o.y + z * o.z;
    var b = o;
    if (d < 0) {
      d = -d;
      b = Quat(-o.w, -o.x, -o.y, -o.z);
    }
    if (d > 0.9995) {
      final q = Quat(w + (b.w - w) * t, x + (b.x - x) * t, y + (b.y - y) * t, z + (b.z - z) * t);
      final n = sqrt(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z);
      return Quat(q.w / n, q.x / n, q.y / n, q.z / n);
    }
    final th = acos(d), s = sin(th);
    final ka = sin((1 - t) * th) / s, kb = sin(t * th) / s;
    return Quat(w * ka + b.w * kb, x * ka + b.x * kb, y * ka + b.y * kb, z * ka + b.z * kb);
  }

  M3 toMatrix() => M3(
        V3(1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)),
        V3(2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)),
        V3(2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)),
      );
}

/// Uma face do dado: os cantos (índices), o centro, a direção para fora, a
/// direção "para cima" do número e o número escrito nela.
class DieFace {
  final List<int> corners;
  final V3 center;
  final V3 normal;
  final V3 up;
  final int value;
  final String label;
  final double inradius;
  const DieFace(this.corners, this.center, this.normal, this.up, this.value, this.label, this.inradius);
}

enum DieKind { d4, d6, d8, d10, d12, d20, d100 }

/// Um dado: os vértices e as faces numeradas como num dado de verdade
/// (faces opostas somam o mesmo valor: 1 oposto ao 20 no D20, 1 ao 6 no D6...).
class DieShape {
  final DieKind kind;
  final List<V3> vertices;
  final List<DieFace> faces;
  const DieShape(this.kind, this.vertices, this.faces);

  int get sides => faces.length;

  DieFace faceWithValue(int value) => faces.firstWhere((f) => f.value == value);

  /// A posição final em que a face com [value] fica virada para quem olha
  /// (eixo z) e com o número de pé (eixo y), com uma leve inclinação para
  /// ver as laterais do dado.
  M3 restingOn(int value, {double tiltX = 0.32, double tiltY = -0.22}) {
    final f = faceWithValue(value);
    final n = f.normal, u = f.up, r = u.cross(n);
    final align = M3(r, u, n); // leva r → x, u → y, n → z
    return M3.axisAngle(const V3(0, 1, 0), tiltY) * M3.axisAngle(const V3(1, 0, 0), tiltX) * align;
  }

  static final Map<DieKind, DieShape> _cache = {};

  /// O D100 é o D10 das dezenas (00, 10... 90); a unidade é outro D10.
  static DieShape of(DieKind kind) => _cache[kind] ??= _build(kind);

  static DieShape _build(DieKind kind) {
    switch (kind) {
      case DieKind.d4:
        return _make(kind, const [V3(1, 1, 1), V3(1, -1, -1), V3(-1, 1, -1), V3(-1, -1, 1)], _hullFaces, first: 1);
      case DieKind.d6:
        return _make(kind, [for (final x in [-1.0, 1.0]) for (final y in [-1.0, 1.0]) for (final z in [-1.0, 1.0]) V3(x, y, z)], _hullFaces, first: 1);
      case DieKind.d8:
        return _make(kind, const [V3(1, 0, 0), V3(-1, 0, 0), V3(0, 1, 0), V3(0, -1, 0), V3(0, 0, 1), V3(0, 0, -1)], _hullFaces, first: 1);
      case DieKind.d12:
        return _make(kind, _dodecahedron(), _hullFaces, first: 1);
      case DieKind.d20:
        return _make(kind, _icosahedron(), _hullFaces, first: 1);
      case DieKind.d10:
      case DieKind.d100:
        return _make(kind, _trapezohedron(), _hullFaces, first: 0, tens: kind == DieKind.d100);
    }
  }

  static List<V3> _icosahedron() {
    const p = 1.618033988749895;
    return [
      for (final a in [-1.0, 1.0])
        for (final b in [-p, p]) ...[V3(0, a, b), V3(a, b, 0), V3(b, 0, a)],
    ];
  }

  static List<V3> _dodecahedron() {
    const p = 1.618033988749895, q = 1 / 1.618033988749895;
    return [
      for (final x in [-1.0, 1.0]) for (final y in [-1.0, 1.0]) for (final z in [-1.0, 1.0]) V3(x, y, z),
      for (final a in [-q, q]) for (final b in [-p, p]) ...[V3(0, a, b), V3(a, b, 0), V3(b, 0, a)],
    ];
  }

  /// D10: dois polos e dez vértices em zigue-zague. A altura dos polos é a
  /// que deixa cada face (um "pipa") plana: h = z0·(1 + cos36°)/(1 − cos36°).
  static List<V3> _trapezohedron() {
    const z0 = 0.105;
    final c = cos(pi / 5);
    final h = z0 * (1 + c) / (1 - c);
    return [
      V3(0, 0, h),
      V3(0, 0, -h),
      for (int i = 0; i < 10; i++) V3(cos(i * pi / 5), sin(i * pi / 5), i.isEven ? z0 : -z0),
    ];
  }

  /// As faces de um sólido convexo: os planos que deixam todos os vértices
  /// do mesmo lado, com os cantos em volta do centro.
  static List<List<int>> _hullFaces(List<V3> v) {
    final faces = <List<int>>[];
    final seen = <String>{};
    final n = v.length;
    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        for (int k = j + 1; k < n; k++) {
          var normal = (v[j] - v[i]).cross(v[k] - v[i]);
          if (normal.length < 1e-9) continue;
          normal = normal.unit;
          final d = normal.dot(v[i]);
          var above = 0, below = 0;
          final onPlane = <int>[];
          for (int m = 0; m < n; m++) {
            final s = normal.dot(v[m]) - d;
            if (s > 1e-6) {
              above++;
            } else if (s < -1e-6) {
              below++;
            } else {
              onPlane.add(m);
            }
          }
          if (above > 0 && below > 0) continue;
          final key = onPlane.join(',');
          if (!seen.add(key)) continue;
          if (above > 0) normal = -normal; // para fora
          // Cantos em volta do centro da face.
          final center = onPlane.fold(const V3(0, 0, 0), (a, m) => a + v[m]) * (1 / onPlane.length);
          final ref = (v[onPlane.first] - center).unit, ref2 = normal.cross(ref);
          onPlane.sort((a, b) {
            final pa = v[a] - center, pb = v[b] - center;
            return atan2(pa.dot(ref2), pa.dot(ref)).compareTo(atan2(pb.dot(ref2), pb.dot(ref)));
          });
          faces.add(onPlane);
        }
      }
    }
    return faces;
  }

  static DieShape _make(DieKind kind, List<V3> raw, List<List<int>> Function(List<V3>) hull, {required int first, bool tens = false}) {
    // Todos os dados com o mesmo tamanho (vértice mais longe = 1).
    final radius = raw.map((p) => p.length).reduce(max);
    final v = [for (final p in raw) p * (1 / radius)];
    final cornersList = hull(v);

    final centers = <V3>[], normals = <V3>[];
    for (final c in cornersList) {
      final center = c.fold(const V3(0, 0, 0), (a, m) => a + v[m]) * (1 / c.length);
      var normal = (v[c[1]] - v[c[0]]).cross(v[c[2]] - v[c[0]]).unit;
      if (normal.dot(center) < 0) normal = -normal;
      centers.add(center);
      normals.add(normal);
    }

    // Numeração: os pares de faces opostas recebem (menor, maior) para que
    // somem sempre o mesmo valor, como nos dados de verdade. As faces são
    // percorridas de cima para baixo, em espiral, para espalhar os números.
    final count = cornersList.length;
    final order = List<int>.generate(count, (i) => i)
      ..sort((a, b) {
        final za = normals[a].z, zb = normals[b].z;
        if ((za - zb).abs() > 1e-6) return zb.compareTo(za);
        return atan2(normals[a].y, normals[a].x).compareTo(atan2(normals[b].y, normals[b].x));
      });
    final values = List<int?>.filled(count, null);
    int low = first, high = first + count - 1;
    for (final i in order) {
      if (values[i] != null) continue;
      final opposite = List<int>.generate(count, (j) => j).where((j) => j != i && values[j] == null && (normals[j] + normals[i]).length < 1e-4).firstOrNull;
      values[i] = low++;
      if (opposite != null) values[opposite] = high--;
    }
    // D4 não tem faces opostas: o laço acima numera em sequência.

    final faces = <DieFace>[];
    for (int i = 0; i < count; i++) {
      final c = cornersList[i];
      final center = centers[i], normal = normals[i];
      // "Para cima" do número: no D10 aponta para o polo (como no dado real),
      // nos outros para o primeiro canto (ou meio da aresta, no D6).
      V3 toward;
      if (kind == DieKind.d10 || kind == DieKind.d100) {
        toward = c.map((m) => v[m]).reduce((a, b) => (a - center).length > (b - center).length ? a : b);
        // O polo é o canto mais afastado do centro da face.
        toward = c.map((m) => v[m]).firstWhere((p) => p.x.abs() < 1e-9 && p.y.abs() < 1e-9, orElse: () => toward);
      } else if (kind == DieKind.d6) {
        toward = (v[c[0]] + v[c[1]]) * 0.5;
      } else {
        toward = v[c[0]];
      }
      var up = toward - center;
      up = (up - normal * up.dot(normal)).unit;
      // Raio do círculo dentro da face (tamanho do número).
      double inr = double.infinity;
      for (int k = 0; k < c.length; k++) {
        final a = v[c[k]], b = v[c[(k + 1) % c.length]];
        final edge = (b - a).unit;
        final toCenter = center - a;
        inr = min(inr, (toCenter - edge * toCenter.dot(edge)).length);
      }
      final value = values[i]!;
      final label = tens ? '${value}0' : _withMark(value, kind);
      faces.add(DieFace(c, center, normal, up, tens ? value * 10 : value, label, inr));
    }
    return DieShape(kind, v, faces);
  }

  /// 6 e 9 ganham um ponto (como nos dados de verdade), para não confundir.
  static String _withMark(int value, DieKind kind) {
    final marked = (value == 6 || value == 9) && kind != DieKind.d6 && kind != DieKind.d8 && kind != DieKind.d4;
    return marked ? '$value.' : '$value';
  }
}
