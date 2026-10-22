import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/services/offline_cards.dart';
import '../../../data/services/update_service.dart';
import '../../widgets/neon.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double? _downloading; // 0 a 1 enquanto baixa as cartas

  Future<void> _downloadCards() async {
    setState(() => _downloading = 0);
    try {
      final count = await OfflineCards.instance.download(progress: (p) {
        if (mounted) setState(() => _downloading = p);
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count cartas salvas no celular.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não deu para baixar: $e')));
    }
    if (mounted) setState(() => _downloading = null);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentBg = themeProvider.backgroundColor;
    final bool isLight = currentBg.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      backgroundColor: currentBg,
      resizeToAvoidBottomInset: false, 
      appBar: AppBar(
        title: Text("Configurações", style: TextStyle(color: textColor)), 
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        foregroundColor: textColor
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CORES
            Text("COR DE FUNDO", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 20,
              children: themeProvider.availableColors.entries.map((entry) {
                bool isSelected = currentBg == entry.value;
                return GestureDetector(
                  onTap: () => themeProvider.setBackgroundColor(entry.value),
                  child: Container(
                    width: 55, height: 55,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? Colors.blueAccent : Colors.grey.withValues(alpha: 0.5), width: isSelected ? 3 : 1),
                      boxShadow: isSelected ? [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.3), blurRadius: 10)] : [],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            // O app é em português; aqui é o idioma que aparece primeiro em "Outras artes".
            Text("IDIOMA DAS CARTAS (EM OUTRAS ARTES)", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              decoration: neonDecoration(AreaColors.profile, neonSurface(context, currentBg), radius: 16, glow: 0.12),
              child: Column(
                children: [
                  ListTile(
                    title: Text("Português (PT-BR)", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    trailing: Icon(
                      themeProvider.cardLanguage == 'pt' ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: themeProvider.cardLanguage == 'pt' ? Colors.blueAccent : textColor.withValues(alpha: 0.3),
                    ),
                    onTap: () => themeProvider.setCardLanguage('pt'),
                  ),
                  Divider(height: 1, color: textColor.withValues(alpha: 0.1)),
                  ListTile(
                    title: Text("Inglês (EN)", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    trailing: Icon(
                      themeProvider.cardLanguage == 'en' ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: themeProvider.cardLanguage == 'en' ? Colors.blueAccent : textColor.withValues(alpha: 0.3),
                    ),
                    onTap: () => themeProvider.setCardLanguage('en'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // CARTAS SEM INTERNET
            Text("CARTAS SEM INTERNET", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              decoration: neonDecoration(AreaColors.profile, neonSurface(context, currentBg), radius: 16, glow: 0.12),
              padding: const EdgeInsets.all(16),
              child: FutureBuilder(
                future: OfflineCards.instance.info(),
                builder: (context, snap) {
                  final info = snap.data;
                  final has = info?.at != null;
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(
                      has
                          ? '${info!.count} cartas salvas (${info.at!.day.toString().padLeft(2, '0')}/${info.at!.month.toString().padLeft(2, '0')}/${info.at!.year}). Sem internet, a busca usa essas cartas (em inglês, sem as imagens).'
                          : 'Baixe todas as cartas (uma versão de cada, em inglês) para buscar sem internet. Use o Wi-Fi: são uns 25 MB para baixar e ficam uns 30 MB no celular.',
                      style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    if (_downloading != null) ...[
                      LinearProgressIndicator(value: _downloading),
                      const SizedBox(height: 6),
                      Text('Baixando... ${(_downloading! * 100).toStringAsFixed(0)}%', style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12)),
                    ] else
                      Row(children: [
                        Expanded(child: FilledButton.icon(onPressed: _downloadCards, icon: const Icon(Icons.download), label: Text(has ? 'Atualizar' : 'Baixar cartas'))),
                        if (has) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              await OfflineCards.instance.delete();
                              setState(() {});
                            },
                            child: const Text('Apagar'),
                          ),
                        ],
                      ]),
                  ]);
                },
              ),
            ),

            const SizedBox(height: 30),

            // VERSÃO DO APP E ATUALIZAÇÃO (GitHub Releases)
            Text("VERSÃO DO APP", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              decoration: neonDecoration(AreaColors.profile, neonSurface(context, currentBg), radius: 16, glow: 0.12),
              child: ListTile(
                title: FutureBuilder<String>(
                  future: UpdateService.currentVersion(),
                  builder: (context, snap) => Text("Versão ${snap.data ?? '...'}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                ),
                trailing: UpdateService.supported
                    ? TextButton(
                        onPressed: () => UpdateService.checkNow(context),
                        child: Text("Procurar atualização"),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}