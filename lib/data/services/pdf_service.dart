import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

class PdfService {
  
  // Mágica Anti-CORS: Tenta baixar a imagem usando 4 caminhos diferentes
  static Future<Uint8List?> _downloadImageBytes(String url) async {
    List<String> urlsToTry = kIsWeb 
      ? [
          'https://api.codetabs.com/v1/proxy?quest=${Uri.encodeComponent(url)}',
          'https://corsproxy.io/?${Uri.encodeComponent(url)}',
          'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}',
          url // Último caso, tenta direto
        ]
      : [url]; // No celular a conexão direta sempre funciona

    for (String tryUrl in urlsToTry) {
      try {
        final response = await http.get(Uri.parse(tryUrl)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
      } catch (e) {
        debugPrint("Falha no proxy: $tryUrl");
      }
    }
    return null; // Retorna nulo se todos falharem
  }

  static Future<void> generateAndPrintDeckPdf(BuildContext context, List<String> imageUrls) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Color(0xFF1E1E24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 20),
            Text(
              "Baixando imagens das cartas...\n(O Web pode ser um pouco mais lento).",
              style: TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    try {
      final pdf = pw.Document();
      final List<pw.MemoryImage> images = [];

      for (String url in imageUrls) {
        final bytes = await _downloadImageBytes(url);
        
        if (bytes != null) {
          images.add(pw.MemoryImage(bytes));
        } else {
          debugPrint("Aviso: Não foi possível carregar a carta $url");
        }
        await Future.delayed(const Duration(milliseconds: 100)); 
      }

      if (images.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("O navegador bloqueou o download das imagens (CORS)."), backgroundColor: Colors.redAccent));
        }
        return;
      }

      const double cardWidth = 63 * PdfPageFormat.mm;
      const double cardHeight = 88 * PdfPageFormat.mm;
      const int cardsPerPage = 9;

      for (int i = 0; i < images.length; i += cardsPerPage) {
        final chunk = images.sublist(i, math.min(i + cardsPerPage, images.length));

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(5 * PdfPageFormat.mm), 
            build: (pw.Context context) {
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: List.generate((chunk.length / 3.0).ceil(), (rowIndex) {
                  final rowCards = chunk.sublist(
                    rowIndex * 3, 
                    math.min((rowIndex + 1) * 3, chunk.length)
                  );

                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: rowCards.map((img) {
                      return pw.Container(
                        width: cardWidth,
                        height: cardHeight,
                        margin: const pw.EdgeInsets.all(1 * PdfPageFormat.mm), 
                        child: pw.Image(img, fit: pw.BoxFit.fill), 
                      );
                    }).toList(),
                  );
                }),
              );
            },
          ),
        );
      }

      if (context.mounted) Navigator.pop(context); 

      final Uint8List pdfBytes = await pdf.save();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'meu_deck_proxy.pdf',
      );

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao gerar PDF: $e")));
      }
    }
  }
}