import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NewsDetailScreen extends StatefulWidget {
  final String url;
  final String title;

  const NewsDetailScreen({super.key, required this.url, required this.title});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Configura o WebView para abrir a URL definitiva exatamente como num navegador
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false; // Tira o loading quando a página termina de carregar
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 14)),
        backgroundColor: const Color(0xFF1E1E24), // Mesma cor dos cards
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // O site real abre aqui
          WebViewWidget(controller: _controller),
          
          // Mostra a bolinha girando enquanto o site carrega
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            ),
        ],
      ),
    );
  }
}