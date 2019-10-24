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

/// Decodes GIF into a set of frames.
///
/// File format: (spec https://www.w3.org/Graphics/GIF/spec-gif89a.txt)
///
/// 1- Header block
///    A gif header is composed of a signature (first 3 bytes) that are ASCII
///    code for "GIF" followed by a 3 byte version block "87a" or "89a".
/// 2- Logical Screen Descriptor
///    Logical Screen Width (uint16)
///    Logical Screen Height (uint16)
///    Packed Fields
///      1 bit  Global Color Table Flag
///      3 bits Color Resolution
///      1 bit  Sort Flag
///      3 bits Size of Global Color Table
///    Background Color Index
///    Pixel Aspect Ratio
/// ******
///
/// Application Extension | Comment Extension
///   [Optional Graphic Control] + Image Descriptor + ImageData or
///   [Optional Graphic Control] + Plain Text Extension
///
/// Image Data:
///   Image seperator [2C]
///   16 bit ImageLeft
///   16 bit ImageTop
///   16 bit ImageWidth
///   16 bit ImageHeight
///   8 bit Packet ImageFlag
///       Local Color Table Flag (1bit)
///       Interlace Flag (1bit)
///       Sort Flag (1bit)
///       Reserved (2bits)
///       Size of local color table (2bits)
///   [Local Color Table]
///
/// Trailer = 0x3B
///
class GifCodec {
  static const String _gifExtension = '.gif';
  static const int _kTrailerByte = 0x3B;

  static const int _kExtensionHeader = 0x21;
  static const int _kImageDescriptorHeader = 0x2C;
  static const int _kImageImageDataHeader = 0x02;

  static const int _plainTextLabelExtensionId = 0x1; // followed by 1 byte block size
  static const int _applicationExtensionId = 0xFF;
  static const int _commentExtensionId = 0xFE;
  static const int _graphicControlExtensionId = 0xF9;

  static int kHeaderSize = 6;

  int logicalWidth;
  int logicalHeight;
  int pixelAspectRatio;
  bool _hasGlobalColorTable;
  bool _colorTableSorted;
  int _bitsPerPixel;
  int _colorTableSize;
  int _backgroundColorIndex;
  int repeatCount = -1;

  ByteData byteData;

  GifCodec(this.byteData) {
    int offset = kHeaderSize;
    logicalWidth = byteData.getUint16(offset, Endian.little);
    offset += 2;
    logicalHeight = byteData.getUint16(offset, Endian.little);
    offset += 2;
    print('gif size = $logicalWidth, $logicalHeight');
    final int flags = byteData.getUint8(offset++);
    _hasGlobalColorTable = (flags & 0x80) != 0;
    _bitsPerPixel = ((flags >> 4) & 7) + 1;
    _colorTableSorted = (flags >> 3) & 0x1 != 0;
    print('Has Global Color Table: $_hasGlobalColorTable , sorted = $_colorTableSorted');
    print('bitsPerPixel = $_bitsPerPixel');
    _colorTableSize = math.pow(2, (flags&7) + 1);
    print('color table size = $_colorTableSize');
    _backgroundColorIndex = byteData.getUint8(offset++);
    pixelAspectRatio = byteData.getUint8(offset++);
    if (pixelAspectRatio != 0) {
      final double aspectRatio = (pixelAspectRatio + 15) / 64;
      print('aspectRatio = $aspectRatio');
    }
    final int numBytesInColorTable = _colorTableSize * 3;
    offset += numBytesInColorTable;

    final int header = byteData.getUint8(offset++);

    while (header != _kTrailerByte) {
      if (header == _kExtensionHeader) {
        final int extensionType = byteData.getUint8(offset++);
        switch(extensionType) {
          case _plainTextLabelExtensionId:
            print('plainText Extension');
            break;
          case _applicationExtensionId:
            print('application extension');
            int blockSize = byteData.getUint8(offset++);
            String appId = _byteDataToAscii(byteData, offset, 8);
            print('   AppId: $appId');
            offset += 8;
            String appAuth = _byteDataToAscii(byteData, offset, 3);
            print('   AppAuth: $appAuth');
            offset += 3;
            // Read sub blocks. Blocks are terminated with 0 length.
            int blockLength = byteData.getUint8(offset++);
            int blockIndex = 0;
            while (blockLength != 0) {
              _readAppExtension(appId, appAuth, blockIndex++, offset, blockLength);
              offset += blockLength;
              blockLength = byteData.getUint8(offset++);
            }
            break;
          case _commentExtensionId:
            print('comment extension');
            break;
          case _graphicControlExtensionId:
            final int byteSize = byteData.getUint8(offset++);
            assert(byteSize >= 4);
            /// 3 bits reserved
            /// 3 bits disposal method
            /// 1 bit user input
            /// 1 bit transparent color flag
            final int flags = byteData.getUint8(offset++);
            final bool hasTransparency = (flags & 1) != 0;
            final int delayTime = byteData.getUint16(offset, Endian.little);
            offset += 2;
            final int transparentColorIndex = byteData.getUint8(offset++);
            if (byteSize > 4) {
              offset += byteSize - 4; // Skip unknown bytes
            }
            final int blockTerminator = byteData.getUint8(offset++);
            if (blockTerminator != 0) {
              throw FormatException();
            }
            print('graphiccontrol extension');
            print('    hasTransparency = $hasTransparency, transparentColorIndex = $transparentColorIndex');
            break;
          default:
            throw FormatException('Unexpected gif extension type $extensionType');
        }
      } else if (header == _kImageDescriptorHeader) {

      } else {
        throw FormatException('Unexpect header code $header');
      }
    }
  }

  void _readAppExtension(String appId, String appAuth, int blockIndex, int offset, int length) {
    if (appId == 'NETSCAPE' && appAuth == '2.0') {
      if (blockIndex != 0) {
        throw const FormatException();
      }
      int header = byteData.getUint8(offset++);
      if (header != 0x1) {
        throw const FormatException();
      }
      repeatCount = byteData.getUint16(offset, Endian.little);
      print('  Repeat count = $repeatCount');
    } else {
      print('Skipping unknown gif app extension $appId, $appAuth');
    }
  }
}

String _byteDataToAscii(ByteData byteData, int offset, int length) {
  final StringBuffer sb = StringBuffer();
  for (int i = 0; i < length; i++) {
    final int byte = byteData.getUint8(offset + i);
    sb.writeCharCode(byte);
  }
  return sb.toString();
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
