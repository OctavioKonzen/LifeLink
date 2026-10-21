import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'scryfall_service.dart';

class PdfService {
  // Baixa direto do Scryfall, no tamanho "large" (672×936, boa qualidade para imprimir).
  static Future<Uint8List?> _downloadImageBytes(String imageUrl) async {
    final url = CardImages.sized(imageUrl, 'large');
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http.get(Uri.parse(url), headers: CardImages.headers).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) return response.bodyBytes;
      } catch (_) {}
    }
    return null;
  }

  static Future<void> generateAndPrintDeckPdf(BuildContext context, List<String> imageUrls) async {
    // Cada imagem é baixada uma vez só (30 Forests = 1 download), 4 de cada vez.
    final unique = imageUrls.toSet().toList();
    final done = ValueNotifier<int>(0);
    var cancelled = false;
    var dialogOpen = true;
    void closeDialog() {
      if (dialogOpen && context.mounted) Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: ValueListenableBuilder<int>(
          valueListenable: done,
          builder: (_, n, _) => Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: unique.isEmpty ? null : n / unique.length),
            const SizedBox(height: 16),
            Text('Baixando as imagens das cartas... $n de ${unique.length}', textAlign: TextAlign.center),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              closeDialog();
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    try {
      final pdf = pw.Document();
      final bytesOf = <String, Uint8List?>{};
      var next = 0;
      Future<void> worker() async {
        while (!cancelled && next < unique.length) {
          final url = unique[next++];
          bytesOf[url] = await _downloadImageBytes(url);
          done.value++;
        }
      }

      await Future.wait([for (var k = 0; k < 4; k++) worker()]);
      if (cancelled) return;

      final memory = {for (final e in bytesOf.entries) if (e.value != null) e.key: pw.MemoryImage(e.value!)};
      final images = [for (final url in imageUrls) if (memory[url] != null) memory[url]!];
      final failed = unique.where((u) => bytesOf[u] == null).length;

      if (images.isEmpty) {
        closeDialog();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não deu para baixar as imagens. Verifique a internet e tente de novo.'), backgroundColor: Colors.redAccent));
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

      final Uint8List pdfBytes = await pdf.save();
      closeDialog();
      if (failed > 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$failed carta${failed > 1 ? 's' : ''} ficou de fora (a imagem não baixou).')));
      }
      await Printing.sharePdf(bytes: pdfBytes, filename: 'meu_deck_proxy.pdf');
    } catch (e) {
      closeDialog();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não deu para gerar o PDF. Tente de novo.')));
      }
    } finally {
      done.dispose();
    }
  }
}