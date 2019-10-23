// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'dart:ui' as ui;
import 'dart:typed_data';


import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

void main() {
  runApp(MyApp());
}

void imageLoaded(ImageInfo imageInfo, bool synchronousCall) {
   imageInfo.image.toByteData().then((ByteData byteData) {
      final GifCodec gif = GifCodec(byteData);
   });
}

class GifCodec implements ui.Codec {
  static const String _gifExtension = '.gif';
  static int kHeaderSize = 6;
  int logicalWidth;
  int logicalHeight;
  int flags;
  int pixelAspectRatio;

  ByteData byteData;

  GifCodec(this.byteData) {
    int offset = kHeaderSize;
    logicalWidth = byteData.getUint16(offset, Endian.little);
    offset += 2;
    logicalHeight = byteData.getUint16(offset, Endian.little);
    offset += 2;
    print('gif size = $logicalWidth, $logicalHeight');
    flags = byteData.getUint8(offset++);
    pixelAspectRatio = byteData.getUint8(offset++);
  }
}

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  double _startAngle = 0, _endAngle = 360, _rotation = 0;

  @override
  Widget build(BuildContext context) {
    final Image image = Image.asset('lib/animated_images/animated_flutter_lgtm.gif');
    final ImageStream stream = image.image.resolve(const ImageConfiguration());
    stream.addListener(const ImageStreamListener(imageLoaded));

    return MaterialApp(
      home: Column(children: <Widget>[
        Center(
            child: Column(children: <Widget>[
              Image.asset('lib/animated_images/animated_flutter_lgtm.gif'),
            ]
            )
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

      canvas.drawCircle(const Offset(220.0, 220.0), 150.0, Paint()
          ..style = PaintingStyle.fill
          ..color = const Color.fromARGB(128, 255, 0, 0));

      canvas.drawCircle(const Offset(380.0, 220.0), 150.0, Paint()
        ..style = PaintingStyle.fill
        ..color = const Color.fromARGB(128, 0, 255, 0));

      canvas.drawCircle(const Offset(300.0, 420.0), 150.0, Paint()
        ..style = PaintingStyle.fill
        ..color = const Color.fromARGB(128, 0, 0, 255));

//    final Int32List colors = Int32List.fromList(<int>[
//      0xFFFF0000, 0xFF00FF00, 0xFF0000FF,
//    ]);
//    final Float32List positions = Float32List.fromList([
//      200.0, 200.0, 400.0, 200.0, 300.0, 400.0,
//    ]);
//    final ui.Vertices vertices = ui.Vertices.raw(VertexMode.triangles,
//        positions , colors: colors);
//    canvas.drawVertices(vertices, BlendMode.lighten, Paint());

    final Int32List colors = Int32List.fromList(<int>[
      0xFFFF0000, 0xFF00FF00, 0xFF0000FF,
      0xFFFF0000, 0xFF00FF00, 0xFF0000FF]);
    final ui.Vertices vertices = ui.Vertices.raw(VertexMode.triangleFan,
        Float32List.fromList([
          150.0, 150.0, 20.0, 10.0, 80.0, 20.0,
          220.0, 15.0, 280.0, 30.0, 300.0, 420.0
        ]), colors: colors);
    canvas.drawVertices(vertices, BlendMode.srcOver, Paint());
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
