import 'package:flutter/material.dart' show Colors;
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

final int columns = 46;
final int rows = 58;
final Duration duration = Duration(seconds: 8);
Size starSize;

enum PaintMode {
  Paths,
  Vertices,
  Batch
}

class Painter extends ChangeNotifier implements CustomPainter
{
  ui.Vertices _allVertices;
  PaintMode _mode = PaintMode.Paths;
  final List<Path> _starPaths = [];
  final List<ui.Vertices> _starVertices = [];
  Duration _timeStamp;

  void makeStars(Rect viewport)
  {
    starSize = Size(viewport.width / columns, viewport.height / rows);

    final List<Offset> allPositions = [];
    final List<Offset> allCoordinates = [];
    final List<int> allIndices = [];

    for(int c = 0; c < columns; c++)
    {
      for (int r = 0; r < rows; r++)
      {
        final List<Offset> positions = [];
        final List<Offset> coords = [
          Offset(0.00, 0.38),
          Offset(0.38, 0.38),
          Offset(0.50, 0.00),
          Offset(0.62, 0.38),
          Offset(1.00, 0.38),
          Offset(0.70, 0.62),
          Offset(0.80, 1.00),
          Offset(0.50, 0.76),
          Offset(0.20, 1.00),
          Offset(0.30, 0.62)
        ];
        final List<int> indices = [
          0, 1, 9,
          1, 2, 3,
          3, 4, 5,
          5, 6, 7,
          7, 8, 9,
          9, 1, 7,
          1, 3, 7,
          3, 5, 7
        ];

        final Offset topLeft = Offset(c * starSize.width, r * starSize.height);

        for(int c = 0; c < coords.length; c++)
          positions.add(topLeft + Offset(coords[c].dx * starSize.width, coords[c].dy * starSize.height));

        final Path path = Path();
        path.moveTo(positions[0].dx, positions[0].dy);
        for(int p = 1; p < positions.length; p++)
          path.lineTo(positions[p].dx, positions[p].dy);
        path.lineTo(positions[0].dx, positions[0].dy);

        final ui.Vertices vertices = ui.Vertices(VertexMode.triangles, positions, textureCoordinates: coords, indices: indices);

        _starPaths.add(path);
        _starVertices.add(vertices);

        allPositions.addAll(positions);
        allCoordinates.addAll(coords);

        for(int i = 0; i < indices.length; i++)
          allIndices.add((((c * rows * positions.length) + (r * positions.length))) + indices[i]);
      }
    }

    _allVertices = ui.Vertices(VertexMode.triangles, allPositions, textureCoordinates: allCoordinates, indices: allIndices);
  }

  @override paint(Canvas canvas, Size size)
  {
    if(_timeStamp == null)
      return;

    final Rect viewport = Offset.zero & size;

    if(_starPaths.length == 0)
      makeStars(viewport);

    canvas.clipRect(viewport);
    canvas.save();

    final double sine = sin((_timeStamp.inMicroseconds.toDouble() / duration.inMicroseconds.toDouble()) * 2 * pi) * 0.75;
    canvas.scale(1.0 + sine, 1.0 + sine);

    canvas.drawColor(Colors.white, BlendMode.srcOver);

    final LinearGradient gradient = LinearGradient(colors: [Colors.red, Colors.blue], tileMode: TileMode.repeated);
    final Paint fill = Paint();
    fill.shader = gradient.createShader(_mode == PaintMode.Paths ? Offset.zero & starSize : Offset.zero & Size(1.0, 1.0));

    final ui.ParagraphBuilder paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle());
    paragraphBuilder.pushStyle(ui.TextStyle(color: Colors.black));

    switch(_mode)
    {
      case PaintMode.Paths:
        for(int p = 0; p < _starPaths.length; p++) { canvas.drawPath(_starPaths[p], fill); }
        paragraphBuilder.addText('Paths - tap to change');
        break;
      case PaintMode.Vertices:
        for(int v = 0; v < _starVertices.length; v++) { canvas.drawVertices(_starVertices[v], BlendMode.srcOver, fill); }
        paragraphBuilder.addText('Vertices - tap to change');
        break;
      case PaintMode.Batch:
        canvas.drawVertices(_allVertices, BlendMode.srcOver, fill);
        paragraphBuilder.addText('Batch - tap to change');
        break;
    }

    canvas.restore();

    final ui.Paragraph paragraph = paragraphBuilder.build();
    paragraph.layout(ui.ParagraphConstraints(width: size.width));
    canvas.drawParagraph(paragraph, Offset(10.0, size.height - 20.0));
  }

  void update(Duration timeStamp) { _timeStamp = timeStamp; notifyListeners(); }
  @override hitTest(Offset position) { _mode = _mode.index < PaintMode.values.length - 1 ? PaintMode.values[_mode.index + 1] : PaintMode.Paths; return true; }
  @override get semanticsBuilder { return null; }
  @override shouldRebuildSemantics(Painter painter) { return false; }
  @override shouldRepaint(Painter painter) { return false; }
}

class Painting extends StatefulWidget { @override PaintingState createState() { return PaintingState(); }}

class PaintingState extends State with SingleTickerProviderStateMixin
{
  Painter _painter;
  Ticker _ticker;

  @override void initState()
  {
    super.initState();
    _painter = Painter();
    _ticker = createTicker(_painter.update);
    _ticker.start();
  }

  @override void dispose()
  {
    _painter.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) { return CustomPaint(painter: _painter, isComplex: false, willChange: true); }
}

void main()
{
  runApp(
    WidgetsApp(
      color: Colors.black,
      showPerformanceOverlay: true,
      title: 'performance',
      onGenerateRoute: (RouteSettings settings) {
        return PageRouteBuilder(pageBuilder: (BuildContext context, Animation<double> a, Animation<double> s) { return Painting(); });
      }
    )
  );
}


