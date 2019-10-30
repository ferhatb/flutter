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
/// Image Descriptor:
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
/// Lempel-Ziv Welch Gif variation
/// LZW takes advantage of repetition inside raster data.
/// The predefined code size determines the size of the dictionary table (called
/// a stringtable, we use when converting from a codestream to a uncompressed
/// charstream.
///
/// The string table for Gif not only includes the color indices but in addition
/// has a ClearCode and EndOfInformationCode.
///
/// Pseudo code for compression:
/// - Initialize string table based on code size (numBits)
/// - set prefix = empty
/// - loop while charstream not empty:
/// -     read nextChar from charstream
/// -     if (stringtable contains prefix+nextChar)
/// -          prefix = prefix + nextChar
/// -     else
/// -          add prefix+nextChar to string table
/// -          output prefix to codestream
/// -          set prefix = nextChar
/// - charstream empty so just output prefix and end
///
/// Basically as we see repeating prefix chains such as ab,abc,abcd we create
/// entries in the stringtable for these common prefixes. Straight LZW runs the
/// risk of overflowing the string table (more bits than you specified as max).
///
/// Pseudo code for decompression:
/// - Initialize string table based on code size (numBits)
/// - read first code , output stringtable content for code
/// - set oldCode = code
/// - read next code
/// - loop
/// -     if code exists in string table
/// -         output string for code to charstream
/// -         prefix = translation for oldCode
/// -         add prefix+first character of translation for code to table
/// -         oldCode = code
/// -     else
/// -         prefix = translation for old
/// -         K = first character of prefix
/// -         output prefix+K to charstream and add to string table
/// -         oldCode = code
/// -
/// The codestream for GIF files uses flexible code sizes. It allows reducing
/// the number of bits stored. The image data block begins with a single byte
/// value called the LZW minimum code size (N). The GIF format allows any value
/// between 2 and 12 bits. Minimum code size is typically based on number of
/// colors. Since we also need a clear and end code, we need (N+1) bits to start
/// with. As larger codes get added to table, the number of bits used for
/// encoding grows. Once we have exhausted 12 bits, a ClearCode is emitted
/// to clear the table to initial state (N+1) and start over.
class GifCodec {
  static const String _gifExtension = '.gif';
  static const int _kEndOfGifStream = 0x3B;

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
    int totalBytes = byteData.lengthInBytes;
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
    int header = 0;
    while (offset < totalBytes) {
       header = byteData.getUint8(offset++);

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
            int blockLength = byteData.getUint8(offset++);
            offset += blockLength;
            print('${_byteDataToAscii(byteData, offset, blockLength)}');
            int trailer = byteData.getUint8(offset++);
            if (trailer != 0) {
              throw const FormatException();
            }
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
              throw const FormatException();
            }
            print('graphiccontrol extension');
            print('    hasTransparency = $hasTransparency, transparentColorIndex = $transparentColorIndex');
            print('    delay = $delayTime');
            break;
          default:
            throw FormatException('Unexpected gif extension type $extensionType');
        }
      } else if (header == _kImageDescriptorHeader) {
        print('Image descriptorHeader');
        final int imageLeft = byteData.getUint16(offset, Endian.little);
        offset += 2;
        final int imageTop = byteData.getUint16(offset, Endian.little);
        offset += 2;
        final int imageWidth = byteData.getUint16(offset, Endian.little);
        offset += 2;
        final int imageHeight = byteData.getUint16(offset, Endian.little);
        offset += 2;
        print('  bounds = $imageLeft,$imageTop : $imageWidth,$imageHeight');
        final int flags = byteData.getUint8(offset++);
        final bool hasLocalColorTable = (flags & 0x80) != 0;
        final bool interlace = (flags & 0x40) != 0;
        final bool sorted = (flags & 0x20) != 0;
        final int localColorTableSize = math.pow(2, (flags&7) + 1);
        // Read local color table.
        if (hasLocalColorTable) {
          offset += 3 * localColorTableSize;
        }
        // Read Image data.
        print('read image data');
        final int lzwMinCodeSize = byteData.getUint8(offset++);
        print('  lzwMinCodeSize = $lzwMinCodeSize');
        final int subBlocksTotalSize = _readSubBlocksLength(byteData, offset);
        print('  subblocks total data size = $subBlocksTotalSize');
        final Uint8List compressedImageData = Uint8List(subBlocksTotalSize);
        offset = _readSubBlocks(byteData, offset, compressedImageData);
//        // Reverse bits.
//        List<int> _reverse = List<int>(256);
//        for (int i = 0; i < 256; i++) {
//          _reverse[i] = ((i << 7) & 0x80) |
//              ((i << 5) & 0x40) |
//              ((i << 3) & 0x20) |
//              ((i << 1) & 0x10) |
//              ((i >> 1) & 0x08) |
//              ((i >> 3) & 0x04) |
//              ((i >> 5) & 0x02) |
//              ((i >> 7) & 0x01);
//        }
//        final int len = compressedImageData.lengthInBytes;
//        for (int i = 0; i < len; i++) {
//          compressedImageData[i] = _reverse[compressedImageData[i]];
//        }i
        final Uint8List imageData = _decompressGif(compressedImageData,
            lzwMinCodeSize, imageWidth * imageHeight);
      } else if (header == _kEndOfGifStream) {
        assert(offset == totalBytes);
        break;
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

class _Dictionary {
  _Dictionary(this.codeSize) {
    clear();
  }

  final int codeSize;
  int _length;
  Map<int, String> dict = <int, String>{};

  int get length => _length;

  String operator [](int code) => dict[code];

  void push(String value) {
    dict[_length++] = value;
  }

  void clear() {
    for (int i = 0; i < codeSize; i++) {
      dict[i] = String.fromCharCode(i);
    }
    // Clear code.
    dict[codeSize] = '';
    // Stop code.
    dict[codeSize + 1] = null;
    _length = codeSize + 1;
  }
}

Uint8List _decompressGif(Uint8List source, int minCodeSizeInBits,
    int numPixels) {
  final List<int> _lsbMask = <int>[0x0, 0x1, 0x3, 0x7, 0xF, 0x1F, 0x3F, 0x7F, 0xFF];

  final Uint8List data = Uint8List(numPixels);
  int writeIndex = 0;
  final int minCodeSize = 1 << minCodeSizeInBits;
  print('minCodeSizeInBits = $minCodeSize');
  final int clearCode = minCodeSize;
  print('clearCode = $clearCode');
  final int stopCode = clearCode + 1;
  final _Dictionary dict = _Dictionary(clearCode + 1);
  final int totalBitsToRead = minCodeSizeInBits + 1;
  int code;
  int previousCode;
  final int sourceLength = source.lengthInBytes;
  int sourcePos = 0;
  int sourceBitsAvailable = 8;
  while (sourcePos < sourceLength) {
    int sourceByte = source[sourcePos];
    previousCode = code;
    // Read numBits from source stream.
    int bitsToRead = totalBitsToRead;
    if (bitsToRead < sourceBitsAvailable) {
      final int shiftR = 8 - sourceBitsAvailable;
      final int lsbMask = _lsbMask[bitsToRead];
      code = (sourceByte >> shiftR) & lsbMask;
      sourceBitsAvailable -= bitsToRead;
    } else if (bitsToRead == sourceBitsAvailable) {
      final int lsbMask = _lsbMask[bitsToRead];
      code = (sourceByte >> (8- sourceBitsAvailable)) & lsbMask;
      sourceBitsAvailable = 8;
      ++sourcePos;
    } else {
      // First read sourceBitsAvailable and then read remaining from remaining
      // bytes in input stream until bitsToRead is 0.
      final int lsbMask = _lsbMask[sourceBitsAvailable];
      code = (sourceByte >> (8 - sourceBitsAvailable)) & lsbMask;
      bitsToRead -= sourceBitsAvailable;
      int bitsRead = sourceBitsAvailable;
      //final int decodedBitCount = sourceBitsAvailable;
      ++sourcePos;
      sourceBitsAvailable = 8;
      sourceByte = source[sourcePos];
      if (bitsToRead < 8) {
        final int shiftR = 8 - sourceBitsAvailable;
        final int lsbMask = _lsbMask[bitsToRead];
        code = code | (((sourceByte >> shiftR) & lsbMask) << bitsRead);
        sourceBitsAvailable -= bitsToRead;
      } else if (bitsToRead == 8) {
        final int lsbMask = _lsbMask[8];
        code = code | ((sourceByte & lsbMask) << bitsRead);
        sourceBitsAvailable = 8;
        ++sourcePos;
      } else {
        // Max number of bits is 12 for GIF LZW. Read 8 bits off of source and
        // remaining bits from next.
        final int lsbMask = _lsbMask[8];
        code = code | ((sourceByte & lsbMask) << bitsRead);
        sourceBitsAvailable = 8;
        ++sourcePos;
        bitsToRead -= 8;
        bitsRead += 8;
        sourceByte = source[sourcePos];
        assert(bitsToRead < 8);
        final int shiftR = 8 - sourceBitsAvailable;
        code = code | (((sourceByte >> shiftR) & _lsbMask[bitsToRead]) << bitsRead);
        sourceBitsAvailable -= bitsToRead;
      }
    }
    print('code read = $code');
    if (code == clearCode) {
      dict.clear();
      continue;
    }
    if (code == stopCode) {
      print('**** Stop code reached ***');
      break;
    }
    if (code < dict.length) {
      if (previousCode != clearCode && previousCode != null) {
        dict.push(dict[previousCode] + dict[code][0]);
      }
    } else {
      if (code != dict.length) {
        throw const FormatException('Invalid compression code');
      }
      dict.push(dict[previousCode] + dict[previousCode][0]);
    }
    final String dataToWrite = dict[code];
    final int len = dataToWrite.length;
    for (int i = 0; i < len; i++) {
      data[writeIndex++] = dataToWrite.codeUnitAt(i);
    }
  }
  return data;
}

String _byteDataToAscii(ByteData byteData, int offset, int length) {
  final StringBuffer sb = StringBuffer();
  for (int i = 0; i < length; i++) {
    final int byte = byteData.getUint8(offset + i);
    sb.writeCharCode(byte);
  }
  return sb.toString();
}

int _readSubBlocksLength(ByteData byteData, int offset) {
  int lengthInBytes = 0;
  int blockLength;
  do {
    blockLength = byteData.getUint8(offset++);
    if (blockLength != 0) {
      lengthInBytes += blockLength;
      offset += blockLength;
    }
  } while (blockLength != 0);
  return lengthInBytes;
}

int _readSubBlocks(ByteData byteData, int offset, Uint8List target) {
  int destIndex = 0;
  int blockLength;
  do {
    blockLength = byteData.getUint8(offset++);
    if (blockLength != 0) {
      for (int i = 0; i < blockLength; i++) {
        target[destIndex++] = byteData.getUint8(offset++);
      }
    }
  } while (blockLength != 0);
  return offset;
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
