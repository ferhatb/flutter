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
  GifCodec(this.byteData) {
    decode();
  }

  static const String _gifExtension = '.gif';
  static const int _kEndOfGifStream = 0x3B;

  static const int _kExtensionHeader = 0x21;
  static const int _kImageDescriptorHeader = 0x2C;
  static const int _kImageImageDataHeader = 0x02;

  static const int _plainTextLabelExtensionId = 0x1; // followed by 1 byte block size
  static const int _applicationExtensionId = 0xFF;
  static const int _commentExtensionId = 0xFE;
  static const int _graphicControlExtensionId = 0xF9;

  // Size of Gif file format header.
  static int kHeaderSize = 6;

  int _logicalWidth;
  int _logicalHeight;
  int _pixelAspectRatio;
  bool _hasGlobalColorTable;
  bool _colorTableSorted;
  int _bitsPerPixel;
  int _globalColorTableSize;
  int _backgroundColorIndex;
  int _repeatCount = -1;
  int _frameCount = 0;

  ByteData byteData;

  int get width => _logicalWidth;

  int get height => _logicalHeight;

  int get repeatCount => _repeatCount;

  int get frameCount => _frameCount;

  bool get colorTableSorted => _colorTableSorted;

  double get aspectRatio => (_pixelAspectRatio == 0) ? 0
      : (_pixelAspectRatio + 15) / 64;

  int get bitsPerPixel => _bitsPerPixel;

  void decode() {
    bool hasTransparency = false;
    int transparentColorIndex;
    int delayTime;

    _frameCount = 0;
    final int totalBytes = byteData.lengthInBytes;
    int offset = kHeaderSize;
    _logicalWidth = byteData.getUint16(offset, Endian.little);
    offset += 2;
    _logicalHeight = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final int flags = byteData.getUint8(offset++);
    _hasGlobalColorTable = (flags & 0x80) != 0;
    _bitsPerPixel = ((flags >> 4) & 7) + 1;
    _colorTableSorted = (flags >> 3) & 0x1 != 0;
    _globalColorTableSize = math.pow(2, (flags&7) + 1);
    _backgroundColorIndex = byteData.getUint8(offset++);
    _pixelAspectRatio = byteData.getUint8(offset++);
    Int32List globalColorTable, activeColorTable;
    // Read Global Color Table
    if (_hasGlobalColorTable) {
      final int numBytesInColorTable = _globalColorTableSize * 3;
      activeColorTable = globalColorTable = Int32List(_globalColorTableSize);
      for (int c = 0; c < _globalColorTableSize; c++) {
        globalColorTable[c] = 0xFF000000 |
        byteData.getUint8(offset++) << 16 |
        byteData.getUint8(offset++) << 8 |
        byteData.getUint8(offset++);
      }
    } else {
      offset += _globalColorTableSize * 3;
    }
    int header = 0;
    while (offset < totalBytes) {
      header = byteData.getUint8(offset++);
      if (header == _kExtensionHeader) {
        final int extensionType = byteData.getUint8(offset++);
        switch(extensionType) {
          case _plainTextLabelExtensionId:
            // Not used. ignoring header and unused data.
            final int headerSize = byteData.getUint8(offset++);
            offset += headerSize;
            int blockLength;
            do {
              blockLength = byteData.getUint8(offset++);
              offset += blockLength;
            } while (blockLength != 0);
            break;
          case _applicationExtensionId:
            final int blockSize = byteData.getUint8(offset++);
            final String appId = _byteDataToAscii(byteData, offset, 8);
            offset += 8;
            final String appAuth = _byteDataToAscii(byteData, offset, 3);
            offset += 3;
            // Read sub blocks. Blocks are terminated with 0 length.
            int blockLength = byteData.getUint8(offset++);
            int blockIndex = 0;
            while (blockLength != 0) {
              _readAppExtension(appId, appAuth, blockIndex++,
                  offset, blockLength);
              offset += blockLength;
              blockLength = byteData.getUint8(offset++);
            }
            break;
          case _commentExtensionId:
            final int blockLength = byteData.getUint8(offset++);
            offset += blockLength;
            final int trailer = byteData.getUint8(offset++);
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
            hasTransparency = (flags & 1) != 0;
            delayTime = byteData.getUint16(offset, Endian.little);
            offset += 2;
            transparentColorIndex = byteData.getUint8(offset++);
            if (byteSize > 4) {
              offset += byteSize - 4; // Skip unknown bytes
            }
            final int blockTerminator = byteData.getUint8(offset++);
            if (blockTerminator != 0) {
              throw const FormatException();
            }
            break;
          default:
            throw FormatException('Unexpected gif extension type $extensionType');
        }
      } else if (header == _kImageDescriptorHeader) {
        final int imageLeft = byteData.getUint16(offset, Endian.little);
        offset += 2;
        final int imageTop = byteData.getUint16(offset, Endian.little);
        offset += 2;
        final int imageWidth = byteData.getUint16(offset, Endian.little);
        offset += 2;
        final int imageHeight = byteData.getUint16(offset, Endian.little);
        offset += 2;
        final int flags = byteData.getUint8(offset++);
        final bool hasLocalColorTable = (flags & 0x80) != 0;
        final bool interlace = (flags & 0x40) != 0;
        final bool sorted = (flags & 0x20) != 0;
        final int localColorTableSize = math.pow(2, (flags&7) + 1);
        // Read local color table.
        if (hasLocalColorTable) {
          activeColorTable = Int32List(localColorTableSize);
          for (int c = 0; c < localColorTableSize; c++) {
            globalColorTable[c] = 0xFF000000 |
            byteData.getUint8(offset++) << 16 |
            byteData.getUint8(offset++) << 8 |
            byteData.getUint8(offset++);
          }
        }
        // Read Image data.
        final int lzwMinCodeSize = byteData.getUint8(offset++);
        final int subBlocksTotalSize = _readSubBlocksLength(byteData, offset);
        final Uint8List compressedImageData = Uint8List(subBlocksTotalSize);
        offset = _readSubBlocks(byteData, offset, compressedImageData);
        final Uint8List imageData = _decompressGif(compressedImageData,
            lzwMinCodeSize, imageWidth * imageHeight);
        _frameCount++;
        // Reset graphic control parameters.
        activeColorTable = globalColorTable;
        hasTransparency = false;
        transparentColorIndex = null;
        delayTime = null;
      } else if (header == _kEndOfGifStream) {
        assert(offset == totalBytes);
        break;
      } else {
        throw FormatException('Unexpect header code $header');
      }
    }
  }

  void _readAppExtension(String appId, String appAuth, int blockIndex,
      int offset, int length) {
    if (appId == 'NETSCAPE' && appAuth == '2.0') {
      if (blockIndex != 0) {
        throw const FormatException();
      }
      final int header = byteData.getUint8(offset++);
      if (header != 0x1) {
        throw const FormatException();
      }
      _repeatCount = byteData.getUint16(offset, Endian.little);
    } else {
      print('Skipping unknown gif app extension $appId, $appAuth');
    }
  }

  static String _byteDataToAscii(ByteData byteData, int offset, int length) {
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < length; i++) {
      final int byte = byteData.getUint8(offset + i);
      sb.writeCharCode(byte);
    }
    return sb.toString();
  }

  static int _readSubBlocksLength(ByteData byteData, int offset) {
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

  static int _readSubBlocks(ByteData byteData, int offset, Uint8List target) {
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

  static List<int> sharedMask = <int>[0x0, 0x1, 0x3, 0x7, 0xF, 0x1F, 0x3F,
    0x7F, 0xFF];

  static Uint8List _decompressGif(Uint8List source, int minCodeSizeInBits,
      int numPixels) {
    final List<int> _lsbMask = sharedMask;
    final Uint8List data = Uint8List(numPixels);
    int writeIndex = 0;
    final int minCodeSize = 1 << minCodeSizeInBits;
    final int clearCode = minCodeSize;
    final int stopCode = clearCode + 1;
    final _Dictionary dict = _Dictionary(clearCode);
    int totalBitsToRead = minCodeSizeInBits + 1;
    int dictionaryLimit = 1 << totalBitsToRead;
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
      if (code == clearCode) {
        dict.clear();
        totalBitsToRead = minCodeSizeInBits + 1;
        dictionaryLimit = 1 << totalBitsToRead;
        continue;
      }
      if (code == stopCode) {
        break;
      }
      if (code < dict.length) {
        if (previousCode != clearCode) {
          final String prefix = dict[code][0];
          dict.push(dict[previousCode] + prefix);
        }
      } else {
        if (code != dict.length) {
          throw const FormatException('Invalid compression code');
        }
        dict.push(dict[previousCode] + dict[previousCode][0]);
      }
      // Once we fill up the dictionary for totalBitsRead, increase number of bits.
      // 12 bits is the max number of bits and has to be followed by a clearCode on the next
      // read.
      if (dict.length == dictionaryLimit && totalBitsToRead < 12) {
        ++totalBitsToRead;
        dictionaryLimit = 1 << totalBitsToRead;
      }
      final String dataToWrite = dict[code];
      final int len = dataToWrite.length;
      for (int i = 0; i < len; i++) {
        data[writeIndex++] = dataToWrite.codeUnitAt(i);
      }
    }
    return data;
  }
}

class _Dictionary {
  _Dictionary(this.codeSize) {
    clear();
  }

  final int codeSize;
  int _length;
  List<String> dict;

  int get length => _length;

  String operator [](int code) => dict[code];

  void push(String value) {
    dict.add(value);
    _length++;
  }

  void clear() {
    dict = <String>[];
    for (int i = 0; i < codeSize; i++) {
      dict.add(String.fromCharCode(i));
    }
    // Clear code.
    dict.add('');
    // Stop code.
    dict.add(null);
    _length = codeSize + 2;
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
