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

  void play(GameSound sound) {
    if (!enabled) return;
    // Segurar o botão muda a vida várias vezes por segundo: no máximo um som
    // do mesmo tipo a cada 90 ms.
    final now = DateTime.now();
    final last = _last[sound];
    if (last != null && now.difference(last) < const Duration(milliseconds: 90)) return;
    _last[sound] = now;
    _pools[sound]?.start(volume: 0.9).catchError((_) => () async {});
  }
}
