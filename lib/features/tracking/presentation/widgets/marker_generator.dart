import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map4d_map/map4d_map.dart';

Future<MFBitmap> createCustomMarkerBitmap(
  String label,
  IconData iconData,
  Color color, {
  double size = 96.0,
}) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);

  // Text layout for Icon
  TextPainter iconPainterStroke = TextPainter(textDirection: TextDirection.ltr);
  iconPainterStroke.text = TextSpan(
    text: String.fromCharCode(iconData.codePoint),
    style: TextStyle(
      fontSize: size * 0.6,
      fontFamily: iconData.fontFamily,
      package: iconData.fontPackage,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.white,
    ),
  );
  iconPainterStroke.layout();

  TextPainter iconPainterFill = TextPainter(textDirection: TextDirection.ltr);
  iconPainterFill.text = TextSpan(
    text: String.fromCharCode(iconData.codePoint),
    style: TextStyle(
      fontSize: size * 0.6,
      fontFamily: iconData.fontFamily,
      package: iconData.fontPackage,
      color: color,
    ),
  );
  iconPainterFill.layout();

  // Text layout for Label
  double fontSize = size * 0.28;
  if (label.length > 5) {
      fontSize = size * 0.22; // smaller font for long labels
  }
  TextPainter labelPainterStroke = TextPainter(textDirection: TextDirection.ltr);
  labelPainterStroke.text = TextSpan(
    text: label,
    style: TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white,
    ),
  );
  labelPainterStroke.layout();

  TextPainter labelPainterFill = TextPainter(textDirection: TextDirection.ltr);
  labelPainterFill.text = TextSpan(
    text: label,
    style: TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: color,
    ),
  );
  labelPainterFill.layout();

  // Calculate canvas dimensions
  final double canvasWidth = math.max(size, labelPainterStroke.width + 10);
  final double canvasHeight = size + (labelPainterStroke.height * 0.5);

  // Draw shadow
  final Paint shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.3)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
  canvas.drawCircle(Offset(canvasWidth / 2, size / 2.5 + 4), size * 0.35, shadowPaint);

  // Paint Icon
  final double iconX = (canvasWidth - iconPainterStroke.width) / 2;
  final double iconY = (size - iconPainterStroke.height) / 2 - size * 0.1;
  iconPainterStroke.paint(canvas, Offset(iconX, iconY));
  iconPainterFill.paint(canvas, Offset(iconX, iconY));

  // Paint Label
  final double labelX = (canvasWidth - labelPainterStroke.width) / 2;
  final double labelY = iconY + iconPainterStroke.height - size * 0.05;
  labelPainterStroke.paint(canvas, Offset(labelX, labelY));
  labelPainterFill.paint(canvas, Offset(labelX, labelY));

  final ui.Image img = await pictureRecorder.endRecording().toImage(
        canvasWidth.toInt(),
        canvasHeight.toInt(),
      );
  final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final Uint8List uint8List = byteData!.buffer.asUint8List();

  return MFBitmap.fromBytes(uint8List);
}
