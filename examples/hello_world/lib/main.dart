// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  double _startAngle = 0, _endAngle = 360, _rotation = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Column(children: <Widget>[
        Center(
          child: Column(children: <Widget>[
            Container(color: Colors.white, width: 600, height: 400, child: CustomPaint(painter: MyPainter(this))),
            Container(color: Colors.white, width: 600, height: 400, child: CustomPaint(painter: PathTransformSample(this)))
            ]
          )
        ),
        Material(child:
          Column(children: <Widget> [
            Slider(
                value: _startAngle, min: 0, max: 360, label: 'Start Angle',
                onChanged: (double value) {setState(() {_startAngle = value;});},
            ),
            Slider(
                value: _endAngle, min: 0, max: 360, label: 'End Angle',
                onChanged: (double value) {setState(() {_endAngle = value;});},
            ),
            Slider(
              value: _rotation, min: 0, max: 180, label: 'Rotation',
              onChanged: (double value) {setState(() {_rotation = value;});},
            ),
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
        ..strokeWidth = 2
        ..color = Colors.redAccent;
//     final double start = myappState._startAngle * math.pi / 180.0;
//     final double rotation = myappState._rotation;// * math.pi / 180.0;
//     final double sweep = (myappState._endAngle - myappState._startAngle) * math.pi / 180.0;
//     //canvas.drawArc(const Rect.fromLTRB(200, 50, 400, 150), start, sweep, false,  paint);
//     final Path path = Path();
//     const double cx = 300.0;
//     const double cy = 100.0;
//     const double rx = 200.0;
//     const double ry = 25.0;
//     //path.addArc(const Rect.fromLTRB(cx - rx, cy - ry, cx + rx, cy + ry), start, sweep);
//     bool clockwise = sweep >= 0;
// //    final Offset startPoint = Offset(rx*math.cos(start) + cx,
// //        ry*math.sin(start+sweep) + cy);
// //    final Offset endPoint = Offset(rx*math.cos(start) + cx,
// //        ry*math.sin(start+sweep) + cy);
//     final Offset startPoint = Offset(cx + (rx*math.cos(start)), cy + (ry * math.sin(start)));
//     final Offset endPoint = Offset(cx + (rx*math.cos(start+sweep)), cy + (ry*math.sin(start+sweep)));
//     path.moveTo(startPoint.dx, startPoint.dy);

//     path.arcToPoint(endPoint, radius: const Radius.elliptical(rx, ry), clockwise: clockwise,
//         largeArc: sweep.abs() > math.pi, rotation: rotation);
//     canvas.drawPath(path, paint);

//     final Path bezierPath = Path();
//     _drawArcWithBezier(cx, cy + 4 * ry, rx, ry, start, sweep, bezierPath);
//     canvas.drawPath(bezierPath, paint);

    final Path path = new Path();
    path.moveTo(0,0);
    path.lineTo(200, 200);
    canvas.drawPath(path, paint);
    final Path transformedPath = new Path();
    final Matrix4 transformMatrix = Matrix4.rotationZ(myappState._startAngle * math.pi / 180.0);
    transformedPath.addPath(path, Offset.zero, matrix4: transformMatrix.storage);
    canvas.drawPath(transformedPath, new Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.green);
  }

  void _drawArcWithBezier(double centerX, double centerY, double radiusX, double radiusY,
      double startAngle, double sweep, Path targetPath) {
    double ratio = sweep.abs() / (math.pi / 2.0);
    if ((1.0 - ratio).abs() < 0.0000001) {
      ratio = 1.0;
    }
    final int segments = math.max(ratio.ceil(), 1);
    final double anglePerSegment = sweep / segments;
    double angle = startAngle;
    for (int segment = 0; segment < segments; segment++) {
      _drawArcSegment(targetPath, centerX, centerY, radiusX, radiusY, angle, anglePerSegment, segment == 0);
      angle += anglePerSegment;
    }
  }

  void _drawArcSegment(Path path, double cx, double cy, double rx, double ry, double startAngle, double sweep,
      bool startPath) {
    final double s = (sweep == 1.5707963267948966)
        ? 0.551915024494
        : sweep == -1.5707963267948966 ? -0.551915024494 : 4 / 3 * math.tan(sweep / 4);

    final double x1 = math.cos(startAngle);
    final double y1 = math.sin(startAngle);
    final double endAngle = startAngle + sweep;
    double x2 = math.cos(endAngle);
    double y2 = math.sin(endAngle);

    double x = x1 - y1 * s;
    double y = y1 + x1 * s;
    x *= rx;
    y *= ry;
    final double cpx1 = x + cx;
    final double cpy1 = y + cy;

    x = x2 + y2 * s;
    y = y2 - x2 * s;
    x *= rx;
    y *= ry;

    final double cpx2 = x + cx;
    final double cpy2 = y + cy;

    x2 *= rx;
    y2 *= ry;
    x2 += cx;
    y2 += cy;
    if (startPath) {
      path.moveTo(cx + x1 * rx, cy + y1 * ry);
    }
    path.cubicTo(cpx1, cpy1, cpx2, cpy2, x2, y2);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class PathTransformSample extends CustomPainter {
  PathTransformSample(this.myappState);

  final MyAppState myappState;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.redAccent;
    final double start = myappState._startAngle * math.pi / 180.0;
    const Rect bounds = Rect.fromLTRB(0, 0, 600, 400);
    canvas.drawRect(bounds, paint);

    final Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(600, 400);
    final Matrix4 matrix = Matrix4.rotationX(start);
    matrix.translate(64.0, 0);
    final Path newPath = path.transform(matrix.storage);
    canvas.drawPath(newPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
