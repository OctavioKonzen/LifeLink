import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/theme_provider.dart';

class CustomBackButton extends StatelessWidget {
  const CustomBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final buttonBgColor = theme.backgroundColor; 
    final isLight = buttonBgColor.computeLuminance() > 0.5;
    
    final buttonIconColor = isLight ? Colors.black87 : Colors.white;
    final borderColor = isLight ? Colors.black26 : Colors.white38;
    final isPt = theme.cardLanguage == 'pt';

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.pop(context); // Função universal de voltar atrás
        },
        child: CustomPaint(
          painter: _EdgeTrianglePainter(fillColor: buttonBgColor, borderColor: borderColor),
          child: SizedBox(
            width: 45,
            height: 90,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 6.0), 
                child: RotatedBox(
                  quarterTurns: 3, 
                  child: Text(isPt ? "Voltar" : "Back", style: TextStyle(color: buttonIconColor, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgeTrianglePainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  const _EdgeTrianglePainter({required this.fillColor, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = fillColor..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 2.0;

    final path = Path();
    path.moveTo(size.width, 0);               
    path.lineTo(0, size.height / 2);          
    path.lineTo(size.width, size.height);     
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _EdgeTrianglePainter oldDelegate) {
    return oldDelegate.fillColor != fillColor || oldDelegate.borderColor != borderColor;
  }
}