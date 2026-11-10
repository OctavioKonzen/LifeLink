import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Os sons do contador de vida (assets/sounds, gerados por tool/make_sounds.py).
enum GameSound { dano, cura, veneno, comandante, morte }

/// O nome de cada som na tela.
const gameSoundNames = {
  GameSound.dano: 'Dano',
  GameSound.cura: 'Cura',
  GameSound.veneno: 'Veneno',
  GameSound.comandante: 'Dano de comandante',
  GameSound.morte: 'Derrota',
};

/// Toca os sons do contador. Dá para desligar (fica salvo no aparelho). Cada
/// lugar da mesa pode ter os próprios sons gravados (CustomSounds): quando tem,
/// toca o gravado no lugar do som padrão.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _key = 'counter_sounds';
  final Map<GameSound, AudioPool> _pools = {};
  final Map<String, Future<AudioPool?>> _custom = {}; // arquivo gravado → pool
  final Map<String, DateTime> _last = {};
  bool enabled = true;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    enabled = (await SharedPreferences.getInstance()).getBool(_key) ?? true;
    await CustomSounds.instance.load();
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

  Future<void> _playCustom(String path) async {
    try {
      final pool = await _custom.putIfAbsent(path, () => AudioPool.create(source: DeviceFileSource(path), maxPlayers: 2).then<AudioPool?>((p) => p).catchError((_) => null));
      await pool?.start(volume: 1);
    } catch (_) {}
  }

  /// O som gravado mudou (gravou de novo ou voltou ao padrão).
  void forget(String path) => _custom.remove(path)?.then((p) => p?.dispose()).catchError((_) {});

  // Segurando o botão: guarda o som e toca uma vez só ao soltar (o mais
  // importante: morte > comandante > veneno > dano > cura).
  bool _holding = false;
  GameSound? _pending;
  int? _pendingSeat;
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
    if (sound != null) play(sound, seat: _pendingSeat);
  }

  /// Toca o som; com [seat], o gravado para esse lugar da mesa, se tiver.
  void play(GameSound sound, {int? seat}) {
    if (!enabled) return;
    if (_holding) {
      if (_pending == null || _rank[sound]! > _rank[_pending]!) {
        _pending = sound;
        _pendingSeat = seat;
      }
      return;
    }
    // Segurar o botão muda a vida várias vezes por segundo: no máximo um som
    // do mesmo tipo a cada 90 ms.
    final key = '${seat ?? ''}${sound.name}';
    final now = DateTime.now();
    final last = _last[key];
    if (last != null && now.difference(last) < const Duration(milliseconds: 90)) return;
    _last[key] = now;
    final path = seat == null ? null : CustomSounds.instance.pathOf(seat, sound);
    if (path != null) {
      _playCustom(path);
      return;
    }
    _pools[sound]?.start(volume: 0.9).catchError((_) => () async {});
  }
}

/// Os sons gravados pela pessoa: um arquivo por lugar da mesa (0 a 5) e por
/// som, guardados só neste celular.
class CustomSounds {
  CustomSounds._();
  static final CustomSounds instance = CustomSounds._();

  /// O tempo máximo de uma gravação.
  static const maxLength = Duration(seconds: 4);

  final _recorder = AudioRecorder();
  final AudioPlayer _preview = AudioPlayer();
  final Set<String> _have = {};
  Directory? _dir;
  String? _recording; // o arquivo sendo gravado

  static String _name(int seat, GameSound sound) => 'p${seat}_${sound.name}.m4a';

  Future<void> load() async {
    if (_dir != null) return;
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/sons');
      await dir.create(recursive: true);
      _dir = dir;
      _have
        ..clear()
        ..addAll([for (final f in dir.listSync()) f.uri.pathSegments.last]);
    } catch (_) {
      // Sem pasta (ex.: testes): só os sons padrão.
    }
  }

  /// O arquivo gravado para esse lugar e som, ou null (usa o padrão).
  String? pathOf(int seat, GameSound sound) {
    final name = _name(seat, sound);
    return _dir != null && _have.contains(name) ? '${_dir!.path}/$name' : null;
  }

  bool has(int seat, GameSound sound) => pathOf(seat, sound) != null;

  /// Começa a gravar (pede o microfone se precisar). Volta false sem permissão.
  Future<bool> start(int seat, GameSound sound) async {
    await load();
    if (_dir == null || !await _recorder.hasPermission()) return false;
    final path = '${_dir!.path}/gravando_${_name(seat, sound)}';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000, sampleRate: 44100, numChannels: 1), path: path);
    _recording = path;
    return true;
  }

  /// Termina a gravação e guarda como o som desse lugar.
  Future<bool> stop(int seat, GameSound sound) async {
    final temp = _recording;
    _recording = null;
    final saved = await _recorder.stop();
    if (temp == null || saved == null || _dir == null) return false;
    final file = File(saved);
    if (!await file.exists() || await file.length() < 512) return false; // gravação vazia
    final name = _name(seat, sound);
    final target = '${_dir!.path}/$name';
    SoundService.instance.forget(target);
    await file.rename(target);
    _have.add(name);
    return true;
  }

  /// Desiste da gravação em andamento.
  Future<void> cancel() async {
    _recording = null;
    await _recorder.cancel().catchError((_) {});
  }

  /// Volta ao som padrão.
  Future<void> remove(int seat, GameSound sound) async {
    final path = pathOf(seat, sound);
    if (path == null) return;
    SoundService.instance.forget(path);
    await File(path).delete().catchError((_) => File(path));
    _have.remove(_name(seat, sound));
  }

  /// Ouve o som desse lugar (o gravado ou o padrão).
  Future<void> preview(int seat, GameSound sound) async {
    final path = pathOf(seat, sound);
    await _preview.stop();
    await _preview.play(path != null ? DeviceFileSource(path) : AssetSource('sounds/${sound.name}.wav'));
  }
}
