// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  double _startAngle = 0, _endAngle = 360, _rotation = 0;
  double _tStart = 0;
  double _tEnd = 100.0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Column(children: <Widget>[
        Center(
          child: Column(children: <Widget>[
            Container(color: Colors.white, width: 600, height: 400, child: CustomPaint(painter: MyPainter(this))),
            //Container(color: Colors.white, width: 600, height: 400, child: CustomPaint(painter: PathTransformSample(this)))
            ]
          )
        ),
        Material(child:
          Column(children: <Widget> [
            Text('t0'),
            Slider(
              value: _tStart, min: 0, max: 100, label: 'T Start',
              onChanged: (double value) {setState(() {_tStart = value;});},
            ),
            Text('t1'),
            Slider(
              value: _tEnd, min: 0, max: 100, label: 'T End',
              onChanged: (double value) {setState(() {_tEnd = value;});},
            ),
//            Slider(
//                value: _startAngle, min: 0, max: 360, label: 'Start Angle',
//                onChanged: (double value) {setState(() {_startAngle = value;});},
//            ),
//            Slider(
//                value: _endAngle, min: 0, max: 360, label: 'End Angle',
//                onChanged: (double value) {setState(() {_endAngle = value;});},
//            ),
//            Slider(
//              value: _rotation, min: 0, max: 180, label: 'Rotation',
//              onChanged: (double value) {setState(() {_rotation = value;});},
//            ),
          ]),
        ),
      ]),
      );
  }
}

class MyPainter extends CustomPainter {
  MyPainter(this.myappState);

  final MyAppState myappState;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.black12;
    final Paint redPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.redAccent;

    final Path path = Path();
    path.moveTo(50, 130);
    path.lineTo(150, 20);
    double p0x = 150;
    double p0y = 20;
    double p1x = 240;
    double p1y = 120;
    double p2x = 320;
    double p2y = 25;
    path.quadraticBezierTo(p1x, p1y, p2x , p2y);

    canvas.drawPath(path, paint);

    Float32List buffer = Float32List(6);
    List<double> points = [p0x, p0y, p1x, p1y, p2x, p2y];
    double t0 = myappState._tStart / 100.0;
    double t1 = myappState._tEnd / 100.0;

    List<ui.PathMetric> metrics = path.computeMetrics().toList();
    double totalLength = 0;
    for (ui.PathMetric m in metrics) {
      totalLength += m.length;
    }
    print('TotalLength = $totalLength');
    Path dashedPath = Path();
    for (final ui.PathMetric measurePath in path.computeMetrics()) {
      double distance = totalLength * t0;
      bool draw = true;
      while (distance < measurePath.length * t1) {
        final double length = 5.0;//dashArray.next;
        if (draw) {
          dashedPath.addPath(measurePath.extractPath(distance, distance + length),
              Offset.zero);
        }
        distance += length;
        draw = !draw;
      }
    }
    canvas.drawPath(dashedPath, redPaint);
  }



//  void _quadTest(Canvas canvas) {
//    final Paint paint = Paint()
//      ..style = PaintingStyle.stroke
//      ..strokeWidth = 3
//      ..color = Colors.black12;
//    final Paint redPaint = Paint()
//      ..style = PaintingStyle.stroke
//      ..strokeWidth = 1
//      ..color = Colors.redAccent;
//
//    final Path path = Path();
//    path.moveTo(50, 130);
//    path.lineTo(150, 20);
//    double p0x = 150;
//    double p0y = 20;
//    double p1x = 240;
//    double p1y = 120;
//    double p2x = 320;
//    double p2y = 25;
//    path.quadraticBezierTo(p1x, p1y, p2x , p2y);
//
//    canvas.drawPath(path, paint);
//
//    Float32List buffer = Float32List(6);
//    List<double> points = [p0x, p0y, p1x, p1y, p2x, p2y];
//    double t0 = myappState._tStart / 100.0;
//    double t1 = myappState._tEnd / 100.0;
//
//    if (t1 > t0) {
//      _chopQuadAt(points, t0, t1, buffer);
//      final Path choppedPath = Path();
//      choppedPath.moveTo(buffer[0], buffer[1]);
//      choppedPath.quadraticBezierTo(buffer[2], buffer[3], buffer[4], buffer[5]);
//      canvas.drawPath(choppedPath, redPaint);
//    }
//  }
//
//  void _cubicTest(Canvas canvas) {
//    final Paint paint = Paint()
//      ..style = PaintingStyle.stroke
//      ..strokeWidth = 3
//      ..color = Colors.black12;
//    final Paint redPaint = Paint()
//      ..style = PaintingStyle.stroke
//      ..strokeWidth = 1
//      ..color = Colors.redAccent;
//
//    final Path path = Path();
//    path.moveTo(50, 130);
//    path.lineTo(150, 20);
//    double p0x = 150;
//    double p0y = 20;
//    double p1x = 40;
//    double p1y = 120;
//    double p2x = 300;
//    double p2y = 130;
//    double p3x = 320;
//    double p3y = 25;
//    path.cubicTo(p1x, p1y, p2x , p2y, p3x, p3y);
//
//    canvas.drawPath(path, paint);
//
//    Float32List buffer = Float32List(8);
//    List<double> points = [p0x, p0y, p1x, p1y, p2x, p2y, p3x, p3y];
//    double t0 = myappState._tStart / 100.0;
//    double t1 = myappState._tEnd / 100.0;
//
//    if (t1 > t0) {
//      _chopCubicAt(points, t0, t1, buffer);
//      final Path choppedPath = Path();
//      choppedPath.moveTo(buffer[0], buffer[1]);
//      choppedPath.cubicTo(buffer[2], buffer[3], buffer[4], buffer[5], buffer[6], buffer[7]);
//      canvas.drawPath(choppedPath, redPaint);
//    }
//  }

  void _drawArcWithBezier(double centerX, double centerY,
      double radiusX, double radiusY, double rotation, double startAngle,
      double sweep, Path targetPath) {
    double ratio = sweep.abs() / (math.pi / 2.0);
    if ((1.0 - ratio).abs() < 0.0000001) {
      ratio = 1.0;
    }
    final int segments = math.max(ratio.ceil(), 1);
    final double anglePerSegment = sweep / segments;
    double angle = startAngle;
    for (int segment = 0; segment < segments; segment++) {
      _drawArcSegment(targetPath, centerX, centerY, radiusX, radiusY, rotation,
          angle, anglePerSegment, segment == 0);
      angle += anglePerSegment;
    }
  }

  void _drawArcSegment(Path path, double centerX, double centerY,
      double radiusX, double radiusY, double rotation, double startAngle,
      double sweep, bool startPath) {
    final double s = 4 / 3 * math.tan(sweep / 4);

    // Rotate unit vector to startAngle and endAngle to use for computing start
    // and end points of segment.
    final double x1 = math.cos(startAngle);
    final double y1 = math.sin(startAngle);
    final double endAngle = startAngle + sweep;
    final double x2 = math.cos(endAngle);
    final double y2 = math.sin(endAngle);

    // Compute scaled curve control points.
    final double cpx1 = (x1 - y1 * s) * radiusX;
    final double cpy1 = (y1 + x1 * s) * radiusY;
    final double cpx2 = (x2 + y2 * s) * radiusX;
    final double cpy2 = (y2 - x2 * s) * radiusY;

    final double endPointX = centerX + x2 * radiusX;
    final double endPointY = centerY + y2 * radiusY;

    final double rotationRad = rotation * math.pi / 180.0;
    final double cosR = math.cos(rotationRad);
    final double sinR = math.sin(rotationRad);
    if (startPath) {
      final double scaledX1 = x1 * radiusX;
      final double scaledY1 = y1 * radiusY;
      if (rotation == 0.0) {
        path.moveTo(centerX + scaledX1, centerY + scaledY1);
      } else {
        final double rotatedStartX = (scaledX1 * cosR) + (scaledY1 * sinR);
        final double rotatedStartY = (scaledY1 * cosR) - (scaledX1 * sinR);
        path.moveTo(centerX + rotatedStartX, centerY + rotatedStartY);
      }
    }
    if (rotation == 0.0) {
      path.cubicTo(centerX + cpx1, centerY + cpy1,
          centerX + cpx2, centerY + cpy2,
          endPointX, endPointY);
    } else {
      final double rotatedCpx1 = centerX + (cpx1 * cosR) + (cpy1 * sinR);
      final double rotatedCpy1 = centerY + (cpy1 * cosR) - (cpx1 * sinR);
      final double rotatedCpx2 = centerX + (cpx2 * cosR) + (cpy2 * sinR);
      final double rotatedCpy2 = centerY + (cpy2 * cosR) - (cpx2 * sinR);
      final double rotatedEndX = centerX + ((endPointX - centerX) * cosR)
          + ((endPointY - centerY) * sinR);
      final double rotatedEndY = centerY + ((endPointY - centerY) * cosR)
          - ((endPointX - centerX) * sinR);
      path.cubicTo(rotatedCpx1, rotatedCpy1, rotatedCpx2, rotatedCpy2,
          rotatedEndX, rotatedEndY);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

//import 'package:flutter/material.dart';
//
//void main() => runApp(MyApp());
//
//class MyApp extends StatelessWidget {
//  @override
//  Widget build(BuildContext context) {
//    return MaterialApp(
//      title: 'Flutter Demo',
//      debugShowCheckedModeBanner: false,
//      theme: ThemeData(
//        primarySwatch: Colors.blue,
//      ),
//      home: MyHomePage(),
//    );
//  }
//}
//
//class MyHomePage extends StatefulWidget {
//  @override
//  _MyHomePageState createState() => _MyHomePageState();
//}
//
//class _MyHomePageState extends State<MyHomePage> {
//  int _counter = 0;
//
//  void _incrementCounter() {
//    setState(() => _counter++);
//  }
//
//  @override
//  Widget build(BuildContext context) {
//    return Scaffold(
////      appBar: AppBar(
////        title: Text('Outline Button Edge Issue'),
////      ),
//      body: Center(
//        child: Column(
//          mainAxisAlignment: MainAxisAlignment.center,
//          children: <Widget>[
//            Text('You have pushed the button this many times:'),
//            Text(
//              '$_counter',
//              style: Theme.of(context).textTheme.display1,
//            ),
//            OutlineButton(
//              child: Text('Incr'),
//              onPressed: _incrementCounter,
//            ),
//          ],
//        ),
//      ),
//    );
//  }
//}
//------------------------------------------------------

//// Copyright 2015 The Chromium Authors. All rights reserved.
//// Use of this source code is governed by a BSD-style license that can be
//// found in the LICENSE file.
//
//import 'dart:math' as math;
//import 'package:flutter/material.dart';
//import 'package:flutter/painting.dart';
//
//void main() => runApp(MyApp());
//
//class MyApp extends StatefulWidget {
//  @override
//  State<StatefulWidget> createState() => MyAppState();
//}
//
//class MyAppState extends State<MyApp> {
//
//  @override
//  Widget build(BuildContext context) {
//    return MaterialApp(
//      home: Container(
//        color:Colors.white,
//        child: Column(children: <Widget>[
//          Center(
//              child: Column(
//                  children: <Widget>[
//                Container(
//                    color: Colors.orange,
//                    width: 400,
//                    height: 600,
//                    child: CustomPaint(
//                        painter: MyPainter(this),
//                    ),
//                ),
//              ]
//            )
//          ),
//        ]),
//      )
//    );
//  }
//}
//
//class MyPainter extends CustomPainter {
//  MyPainter(this.myappState);
//
//  final MyAppState myappState;
//
//  @override
//  void paint(Canvas canvas, Size size) {
//    final Paint paint = Paint()
//      ..style = PaintingStyle.fill
//      ..color = Colors.redAccent;
//    final Paint paintBlue = Paint()
//      ..style = PaintingStyle.fill
//      ..blendMode = BlendMode.multiply
//      ..color = Colors.blue;
//    final Paint clearPaint = Paint()
//      ..style = PaintingStyle.fill
//      ..blendMode = BlendMode.clear
//      ..color = Colors.white;
//    canvas.drawRect(const Rect.fromLTWH(50, 50, 250, 350), paint);
//    canvas.drawRect(const Rect.fromLTWH(70, 70, 250, 350), paintBlue);
//    canvas.drawRect(const Rect.fromLTWH(150, 150, 250, 350), clearPaint);
//    //canvas.drawColor(Colors.white, BlendMode.clear);
//  }
//
//  @override
//  bool shouldRepaint(CustomPainter oldDelegate) => true;
//}

