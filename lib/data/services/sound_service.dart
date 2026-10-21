import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Os sons do contador de vida (assets/sounds, gerados por tool/make_sounds.py).
enum GameSound { dano, cura, veneno, comandante, morte }

/// Toca os sons do contador. Dá para desligar (fica salvo no aparelho).
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _key = 'counter_sounds';
  final Map<GameSound, AudioPool> _pools = {};
  final Map<GameSound, DateTime> _last = {};
  bool enabled = true;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    enabled = (await SharedPreferences.getInstance()).getBool(_key) ?? true;
    for (final s in GameSound.values) {
      try {
        // Vários ao mesmo tempo: toques rápidos não cortam o som anterior.
        _pools[s] = await AudioPool.create(source: AssetSource('sounds/${s.name}.wav'), maxPlayers: 3);
      } catch (_) {
        // Sem áudio (ex.: testes): o contador funciona sem som.
      }
    }
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    await (await SharedPreferences.getInstance()).setBool(_key, value);
  }

  // Segurando o botão: guarda o som e toca uma vez só ao soltar (o mais
  // importante: morte > comandante > veneno > dano > cura).
  bool _holding = false;
  GameSound? _pending;
  static const _rank = {GameSound.cura: 1, GameSound.dano: 2, GameSound.veneno: 3, GameSound.comandante: 4, GameSound.morte: 5};

  void beginHold() {
    _holding = true;
    _pending = null;
  }

  void endHold() {
    if (!_holding) return;
    _holding = false;
    final sound = _pending;
    _pending = null;
    if (sound != null) play(sound);
  }

  void play(GameSound sound) {
    if (!enabled) return;
    if (_holding) {
      if (_pending == null || _rank[sound]! > _rank[_pending]!) _pending = sound;
      return;
    }
    // Segurar o botão muda a vida várias vezes por segundo: no máximo um som
    // do mesmo tipo a cada 90 ms.
    final now = DateTime.now();
    final last = _last[sound];
    if (last != null && now.difference(last) < const Duration(milliseconds: 90)) return;
    _last[sound] = now;
    _pools[sound]?.start(volume: 0.9).catchError((_) => () async {});
  }
}
