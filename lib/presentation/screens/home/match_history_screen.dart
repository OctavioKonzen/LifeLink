import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/theme_provider.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedHistory = prefs.getStringList('match_history') ?? [];
    
    setState(() {
      _history = savedHistory.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('match_history');
    setState(() => _history = []);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final bgColor = themeProvider.backgroundColor;
    final bool isLight = bgColor.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;
    final bool isPt = themeProvider.cardLanguage == 'pt';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(isPt ? "Histórico de Partidas" : "Match History", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: isPt ? "Limpar Histórico" : "Clear History",
              onPressed: () => _clearHistory(),
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, size: 80, color: textColor.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(isPt ? "Nenhuma partida registada ainda." : "No matches recorded yet.", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final match = _history[index];
                    final List<dynamic> players = match['players'];
                    final String winner = match['winner'];
                    final String date = match['date'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isLight ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF1E1E24),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withValues(alpha: winner != "Empate" ? 0.3 : 0.0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        leading: CircleAvatar(
                          backgroundColor: winner != "Empate" ? Colors.amber.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                          child: Icon(Icons.emoji_events, color: winner != "Empate" ? Colors.amber : Colors.grey),
                        ),
                        title: Text(
                          winner != "Empate" ? (isPt ? "Vencedor: $winner" : "Winner: $winner") : (isPt ? "Empate (Todos Morreram)" : "Draw (All Died)"),
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Padding(
                          // AQUI ESTÁ A CORREÇÃO: EdgeInsets.only(top: 8.0)
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isPt ? "Jogadores: ${players.join(', ')}" : "Players: ${players.join(', ')}", style: TextStyle(color: textColor.withValues(alpha: 0.7))),
                              const SizedBox(height: 4),
                              Text(date, style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}