import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/services/update_service.dart';
import '../../widgets/neon.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentBg = themeProvider.backgroundColor;
    final bool isLight = currentBg.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;
    final bool isPt = themeProvider.cardLanguage == 'pt';

    return Scaffold(
      backgroundColor: currentBg,
      resizeToAvoidBottomInset: false, 
      appBar: AppBar(
        title: Text(isPt ? "Configurações" : "Settings", style: TextStyle(color: textColor)), 
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
            Text(isPt ? "COR DE FUNDO" : "BACKGROUND COLOR", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold)),
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

            // IDIOMA DAS CARTAS E APP
            Text(isPt ? "IDIOMA DO APP E CARTAS" : "APP & CARD LANGUAGE", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold)),
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
                    title: Text("English (EN)", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
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

            // VERSÃO DO APP E ATUALIZAÇÃO (GitHub Releases)
            Text(isPt ? "VERSÃO DO APP" : "APP VERSION", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              decoration: neonDecoration(AreaColors.profile, neonSurface(context, currentBg), radius: 16, glow: 0.12),
              child: ListTile(
                title: FutureBuilder<String>(
                  future: UpdateService.currentVersion(),
                  builder: (context, snap) => Text(isPt ? "Versão ${snap.data ?? '...'}" : "Version ${snap.data ?? '...'}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                ),
                trailing: UpdateService.supported
                    ? TextButton(
                        onPressed: () => UpdateService.checkNow(context),
                        child: Text(isPt ? "Procurar atualização" : "Check for update"),
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