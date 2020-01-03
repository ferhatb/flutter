// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => MyAppState();
}

class MyAppState extends State {

  MyAppState() {
    createTestImage().then((ui.Image image) {
      setState(() { testImage = image; });
    });
  }

  ui.Image testImage;


  @override
  Widget build(BuildContext context) {
    return Center(
      //child: Transform(transform: Matrix4.rotationY(degToPi(45)),
      child: Column(children: <Widget>[
        //Image(image: AssetImage('lib/animated_images/pngsample1.png')),
        SizedBox(
          width: 300, height: 500,
          child: testImage == null
              ? const Text('loading', textDirection: TextDirection.ltr)
              : CustomPaint(painter: MyPainter(testImage)),
        ),
      ]),
      //),
    );
  }
}

Future<ui.Image> createTestImage({int width = 100, int height = 50}) {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  const AssetImage image = AssetImage('lib/animated_images/pngsample1.png');
  image.resolve(ImageConfiguration.empty).addListener(
      ImageStreamListener(
          (ImageInfo image, bool synchronousCall) {
            completer.complete(image.image);
          }
      )
  );
  return completer.future;
}


class MyPainter extends CustomPainter {
  MyPainter(this.image);

  ui.Image image;

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
  @override
  void paint(Canvas canvas, Size size) {
    if (image != null) {
      canvas.drawImage(image, Offset(0, 0), Paint());
    }
    final paint = Paint()..color = Color(0xFFFF0000);
    Path path = new Path();
    path.moveTo(0,0);
    path.lineTo(300,0);
    path.lineTo(300,500);
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(100, 100), 80, Paint()..color = Color(0xFFFF00FF));
//    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
//        paint);
  //print('${new Paint().}');
  }
//    Path path = new Path();
//
//    if (curveData.controlPointCount == 3) {
//      Offset start = curveData.readOffset(0);
//      Offset cp = curveData.readOffset(1);
//      Offset end = curveData.readOffset(2);
//      path.moveTo(start.dx, start.dy);
//      path.quadraticBezierTo(cp.dx, cp.dy, end.dx, end.dy);
//    } else {
//      Offset start = curveData.readOffset(0);
//      Offset cp1 = curveData.readOffset(1);
//      Offset cp2 = curveData.readOffset(2);
//      Offset end = curveData.readOffset(3);
//      path.moveTo(start.dx, start.dy);
//      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
//    }
//
//    Rect bounds = path.getBounds();
//    canvas.drawRect(bounds,
//        new Paint()
//          ..style = PaintingStyle.stroke
//          ..color = Color(0x80000000));
//    canvas.drawPath(path, new Paint()..color= Colors.black54);
//  }
}
