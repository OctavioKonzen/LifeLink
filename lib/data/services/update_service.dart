// Atualização do app pelo próprio app (Android, APK fora da Play Store), igual
// ao Pocketdex. Ao abrir, confere a última versão publicada em GitHub Releases
// (github.com/OctavioKonzen/LifeLink/releases). Se for mais nova que a instalada,
// mostra a janela "Nova versão disponível" e, ao aceitar, baixa o APK e abre
// o instalador do Android (a confirmação final é sempre do Android).
//
// As versões são publicadas pelo workflow .github/workflows/android-release.yml
// sempre que a versão do pubspec.yaml muda na main.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppRelease {
  final String version; // "1.2.0"
  final String apkUrl;
  final String notes;
  const AppRelease(this.version, this.apkUrl, this.notes);
}

class UpdateService {
  UpdateService._();

  static const _latest = 'https://api.github.com/repos/OctavioKonzen/LifeLink/releases/latest';
  static const apk64Bits = 'LifeLink.apk';
  static const apk32Bits = 'LifeLink_32bits.apk';
  static bool _checked = false;

  /// "1.10.0" > "1.9.2"
  static bool isNewer(String candidate, String current) {
    List<int> parts(String v) =>
        v.replaceFirst(RegExp(r'^(?:v|apk-)'), '').split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final a = parts(candidate), b = parts(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Celular antigo (ARM de 32 bits)? `Platform.version` termina com
  /// "on \"android_arm\"" nesses aparelhos e "android_arm64" nos atuais.
  static bool get is32Bits => !kIsWeb && Platform.version.contains('"android_arm"');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<AppRelease?> latestRelease() async {
    final response = await http
        .get(Uri.parse(_latest), headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final apks = (json['assets'] as List? ?? []).cast<Map<String, dynamic>>().where((a) => (a['name'] as String).endsWith('.apk')).toList();
    final want = is32Bits ? apk32Bits : apk64Bits;
    final apk = apks.where((a) => a['name'] == want).firstOrNull ?? apks.firstOrNull;
    if (apk == null) return null;
    return AppRelease(
      (json['tag_name'] as String).replaceFirst(RegExp(r'^(?:v|apk-)'), ''),
      apk['browser_download_url'] as String,
      (json['body'] as String? ?? '').trim(),
    );
  }

  static Future<String> currentVersion() async => (await PackageInfo.fromPlatform()).version;

  /// Confere uma vez por abertura do app.
  static Future<void> checkOnStart(BuildContext context) async {
    if (_checked || !supported) return;
    _checked = true;
    try {
      await _check(context, quiet: true);
    } catch (_) {
      // Sem internet ou GitHub fora do ar: tenta na próxima abertura.
    }
  }

  /// Botão "Procurar atualização" das Configurações.
  static Future<void> checkNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _check(context, quiet: false);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Não foi possível procurar agora. Confira a internet.')));
    }
  }

  static Future<void> _check(BuildContext context, {required bool quiet}) async {
    final current = await currentVersion();
    final release = await latestRelease();
    if (!context.mounted) return;
    if (release == null || !isNewer(release.version, current)) {
      if (!quiet) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Você já tem a versão mais recente ($current).')));
      }
      return;
    }
    await showDialog(context: context, builder: (_) => _UpdateDialog(release: release, current: current));
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppRelease release;
  final String current;
  const _UpdateDialog({required this.release, required this.current});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  String? _error;

  void _update() {
    setState(() {
      _progress = 0;
      _error = null;
    });
    OtaUpdate().execute(widget.release.apkUrl, destinationFilename: 'lifelink-${widget.release.version}.apk').listen(
      (event) {
        if (!mounted) return;
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            setState(() => _progress = (double.tryParse(event.value ?? '') ?? 0) / 100);
          case OtaStatus.INSTALLING:
          case OtaStatus.INSTALLATION_DONE:
            setState(() => _progress = 1);
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            setState(() {
              _progress = null;
              _error = 'Permita que o LifeLink instale apps (o Android vai pedir) e tente de novo.';
            });
          default:
            setState(() {
              _progress = null;
              _error = 'Não foi possível baixar a atualização. Tente de novo.';
            });
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _progress = null;
            _error = 'Não foi possível baixar a atualização. Tente de novo.';
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloading = _progress != null;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.system_update, color: Colors.blueAccent),
        SizedBox(width: 10),
        Expanded(child: Text('Nova versão disponível!', style: TextStyle(color: Colors.white))),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Versão ${widget.release.version} (você tem a ${widget.current}).', style: const TextStyle(color: Colors.white)),
          if (widget.release.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(child: Text(widget.release.notes, style: const TextStyle(color: Colors.white60))),
            ),
          ],
          if (downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress == 0 ? null : _progress, color: Colors.blueAccent),
            const SizedBox(height: 6),
            Text(_progress! >= 1 ? 'Abrindo o instalador...' : 'Baixando... ${(_progress! * 100).round()}%',
                style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(downloading ? 'Fechar' : 'Depois')),
        ElevatedButton(onPressed: downloading ? null : _update, child: const Text('Atualizar')),
      ],
    );
  }
}
