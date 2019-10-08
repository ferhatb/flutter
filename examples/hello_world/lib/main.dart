// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'dart:ui' as ui;
import 'dart:typed_data';


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
            Container(color: Colors.white, width: 600, height: 600, child: CustomPaint(painter: MyPainter(this))),
            //Container(color: Colors.white, width: 600, height: 400, child: CustomPaint(painter: PathTransformSample(this)))
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
//    const Rect paintRect = Rect.fromLTRB(50, 50, 300, 300);
//    const Rect shaderRect = Rect.fromLTRB(50, 50, 100, 100);
//    final Paint paint = Paint()
//        ..shader = RadialGradient(
//            tileMode: TileMode.repeated,
//            center: Alignment.center,
//            colors: [Colors.black, Colors.blue]
//        ).createShader(shaderRect);
//    final Path path = Path();
//    path.addRect(paintRect);
//    canvas.drawPath(path, paint);
    final ui.Vertices vertices = ui.Vertices.raw(VertexMode.triangleFan,
        Float32List.fromList([
          150.0, 150.0, 20.0, 10.0, 80.0, 20.0,
          220.0, 15.0, 280.0, 30.0, 300.0, 420.0
        ]));
    canvas.drawVertices(vertices, BlendMode.srcOver, new Paint());
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

