// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_util' as js_util;
import 'dart:async';
import 'dart:html' as html;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

/// The HTML engine used by the current browser.
enum BrowserEngine {
  /// The engine that powers Chrome, Samsung Internet Browser, UC Browser,
  /// Microsoft Edge, Opera, and others.
  blink,

  /// The engine that powers Safari.
  webkit,

  /// The engine that powers Firefox.
  firefox,

  /// We were unable to detect the current browser engine.
  unknown,
}

/// Lazily initialized current browser engine.
BrowserEngine _browserEngine;

/// Returns the [BrowserEngine] used by the current browser.
///
/// This is used to implement browser-specific behavior.
BrowserEngine get browserEngine => _browserEngine ??= _detectBrowserEngine();

BrowserEngine _detectBrowserEngine() {
  final String vendor = html.window.navigator.vendor;
  if (vendor == 'Google Inc.') {
    return BrowserEngine.blink;
  } else if (vendor == 'Apple Computer, Inc.') {
    return BrowserEngine.webkit;
  } else if (vendor == '') {
    // An empty string means firefox:
    // https://developer.mozilla.org/en-US/docs/Web/API/Navigator/vendor
    return BrowserEngine.firefox;
  }

  // Assume blink otherwise, but issue a warning.
  print('WARNING: failed to detect current browser engine.');

  return BrowserEngine.unknown;
}

void main() {
  runApp(MyApp());
}

// Feature detection for createImageBitmap.
bool _browserFeatureCreateImageBitmap;
bool get _browserSupportsCreateImageBitmap =>
    _browserFeatureCreateImageBitmap ??
        js_util.hasProperty(html.window, 'createImageBitmap');

int frameIndex = 0;
bool loaded = false;
void imageLoaded(ImageInfo imageInfo, bool synchronousCall) {
  if (loaded) return;
  loaded = true;
  String src =
      'https://images.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png';
      //'assets/lib/animated_images/animated_flutter_lgtm.gif';

      html.HttpRequest.request(src,
      responseType: 'arraybuffer').then((html.HttpRequest req) {
    final ByteBuffer buffer = req.response;
    final ByteData byteData = ByteData.view(buffer);
    _imageLoaded2(byteData);
  }, onError: (dynamic error) {
    // CORS error.
    final html.ImageElement imageElement = html.ImageElement();
    imageElement.src = src;
    imageElement.decode().then((dynamic _) {
      
    });
  });
}

void _imageLoaded2(ByteData byteData) {
  final GifCodec gif = GifCodec(byteData);
  gif.decode();
  final html.CanvasElement canvas = html.CanvasElement();
  canvas.width = 1000;
  canvas.height = 1000;
  html.document.body.append(canvas);
  final html.CanvasRenderingContext2D ctx = canvas.context2D;

  Function drawNextFrame;

  final _GifFrame frame = gif.frames[frameIndex++];
  if (frameIndex == gif.frameCount) {
    frameIndex = 0;
  }

  final html.ImageData imageData = frame.readImageData();

  if (_browserSupportsCreateImageBitmap) {
    final dynamic imageBitmapPromise = js_util.callMethod(
        html.window, 'createImageBitmap',
        <dynamic>[imageData]);
    final Function imageBitmapLoaded = (dynamic value) {
      js_util.callMethod(ctx, 'drawImage', <dynamic>[
        value,
        0,
        0,
        frame.width,
        frame.height,
        200,
        100,
        2 * frame.width,
        2 * frame.height
      ]);
    };
    html.promiseToFuture<dynamic>(imageBitmapPromise).then((
        dynamic imageBitmap) {
      imageBitmapLoaded(imageBitmap);
    });
  } else {
    if (browserEngine == BrowserEngine.webkit) {
      html.CanvasElement canvas = html.CanvasElement(
          width: frame.width, height: frame.height);
      final dynamic offscreenCtx = js_util.callMethod(
          canvas, 'getContext', <dynamic>['2d']);
      assert(offscreenCtx != null);
      js_util.callMethod(
          offscreenCtx, 'putImageData', <dynamic>[imageData, 0, 0]);
      js_util.callMethod(ctx, 'drawImage', <dynamic>[
        canvas,
        0,
        0,
        frame.width,
        frame.height,
        0,
        0,
        2 * frame.width,
        2 * frame.height
      ]);
    } else {
      // Drawing ImageData scaled/transformed to target context.
      final html.OffscreenCanvas canvas = html.OffscreenCanvas(
          frame.width, frame.height);
      final dynamic offscreenCtx = js_util.callMethod(
          canvas, 'getContext', <dynamic>['2d']);
      assert(offscreenCtx != null);
      js_util.callMethod(
          offscreenCtx, 'putImageData', <dynamic>[imageData, 0, 0]);
      js_util.callMethod(ctx, 'drawImage', <dynamic>[
        canvas,
        0,
        0,
        frame.width,
        frame.height,
        0,
        0,
        2 * frame.width,
        2 * frame.height
      ]);
    }
  }
//        // Drawing ImageData scaled/transformed to target context.
//        html.OffscreenCanvas canvas = html.OffscreenCanvas(frame.width, frame.height);
//        dynamic offscreenCtx = js_util.callMethod(canvas, 'getContext', <dynamic>['2d']);
//        assert(offscreenCtx != null);
//        js_util.callMethod(
//            offscreenCtx, 'putImageData', <dynamic>[imageData, 0, 0]);
//        js_util.callMethod(ctx, 'drawImage', <dynamic>[canvas, 0, 0, frame.width, frame.height, 0, 0, 2 * frame.width, 2 * frame.height]);
//
//    if (frameIndex == gif.frames.length) frameIndex = 0;
//    Timer(Duration(milliseconds: 30), drawNextFrame);
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
///
class GifCodec {
  GifCodec(this.byteData);

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

  ByteData byteData;
  List<_GifFrame> _frames;

  List<_GifFrame> get frames => _frames;

  int get width => _logicalWidth;

  int get height => _logicalHeight;

  int get repeatCount => _repeatCount;

  int get frameCount => _frames == null ? 0 : _frames.length;

  bool get colorTableSorted => _colorTableSorted;

  double get aspectRatio => (_pixelAspectRatio == 0) ? 0
      : (_pixelAspectRatio + 15) / 64;

  int get bitsPerPixel => _bitsPerPixel;

  void decode() {
    _frames = <_GifFrame>[];
    bool hasTransparency = false;
    int transparentColorIndex;
    int delayTime;
    // The disposal method specifies the way in which the graphic is to be
    // used after rendering.
    //   0 - No disposal specified
    //   1 - Do not dispose. The graphic is left in place.
    //   2 - Restore to background color (the area should be cleared to
    //       background color.
    //   3 - Restore to previous. The decoder is required to
    //       to restore the area after the last disposal method.
    int disposalMethod;

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
    Uint32List globalColorTable, activeColorTable;
    // Read Global Color Table
    if (_hasGlobalColorTable) {
      final int numBytesInColorTable = _globalColorTableSize * 3;
      activeColorTable = globalColorTable =
          _readColorTable(offset, _globalColorTableSize);
      offset += 3 * _globalColorTableSize;
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
            offset = _readPlainTextLabelExtension(offset);
            break;
          case _applicationExtensionId:
            offset = _readApplicationExtensions(offset);
            break;
          case _commentExtensionId:
            offset = _readCommentExtension(offset);
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
            disposalMethod = (flags >> 2) & 7;
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
          activeColorTable = _readColorTable(offset, localColorTableSize);
          offset += 3 * localColorTableSize;
        }
        // Read Image data.
        final int lzwMinCodeSize = byteData.getUint8(offset++);
        final int subBlocksTotalSize = _readSubBlocksLength(byteData, offset);
        final Uint8List compressedImageData = Uint8List(subBlocksTotalSize);
        offset = _readSubBlocks(byteData, offset, compressedImageData);
        final Uint8ClampedList imageData = _decompressGif(compressedImageData,
            lzwMinCodeSize, imageWidth * imageHeight, activeColorTable,
            hasTransparency ? transparentColorIndex : -1,
            _frames.isEmpty ? null : _frames.last);
        _frames.add(_GifFrame(imageWidth, imageHeight, imageData,
            disposalMethod));
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

  int _readPlainTextLabelExtension(int offset) {
    // Not used. ignoring header and unused data.
    final int headerSize = byteData.getUint8(offset++);
    offset += headerSize;
    int blockLength;
    do {
      blockLength = byteData.getUint8(offset++);
      offset += blockLength;
    } while (blockLength != 0);
    return offset;
  }

  int _readApplicationExtensions(int offset) {
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
    return offset;
  }

  int _readCommentExtension(int offset) {
    final int blockLength = byteData.getUint8(offset++);
    offset += blockLength;
    final int trailer = byteData.getUint8(offset++);
    if (trailer != 0) {
      throw const FormatException();
    }
    return offset;
  }

  Uint32List _readColorTable(int offset, int colorCount) {
    final Uint32List colorTable = Uint32List(colorCount);
    for (int c = 0; c < colorCount; c++) {
      colorTable[c] = 0xFF000000 |
      byteData.getUint8(offset++) |
      byteData.getUint8(offset++) << 8 |
      byteData.getUint8(offset++) << 16;
    }
    return colorTable;
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

  static Uint8ClampedList _decompressGif(Uint8List source, int minCodeSizeInBits,
      int numPixels, Uint32List colorTable, int transparentColorIndex,
      _GifFrame _priorFrame) {
    final List<int> _lsbMask = sharedMask;
    const int bytesPerPixel = 4;
    final Uint8ClampedList data = Uint8ClampedList(numPixels * bytesPerPixel);
    int writeIndex = 0;
    final int minCodeSize = 1 << minCodeSizeInBits;
    final int clearCode = minCodeSize;
    final int stopCode = clearCode + 1;
    //final _Dictionary dict = _Dictionary(clearCode);
    int totalBitsToRead = minCodeSizeInBits + 1;
    int dictionaryLimit = 1 << totalBitsToRead;
    int code;
    int previousCode;
    final int sourceLength = source.lengthInBytes;
    int sourcePos = 0;
    int sourceBitsAvailable = 8;
    final List<String> dictionary = <String>[];
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
        _clearDictionary(dictionary, minCodeSize);
        totalBitsToRead = minCodeSizeInBits + 1;
        dictionaryLimit = 1 << totalBitsToRead;
        continue;
      }
      if (code == stopCode) {
        break;
      }
      if (code < dictionary.length) {
        if (previousCode != clearCode) {
          final String prefix = dictionary[code][0];
          dictionary.add(dictionary[previousCode] + prefix);
        }
      } else {
        if (code != dictionary.length) {
          throw const FormatException('Invalid compression code');
        }
        dictionary.add(dictionary[previousCode] + dictionary[previousCode][0]);
      }
      // Once we fill up the dictionary for totalBitsRead, increase number of bits.
      // 12 bits is the max number of bits and has to be followed by a clearCode on the next
      // read.
      if (dictionary.length == dictionaryLimit && totalBitsToRead < 12) {
        ++totalBitsToRead;
        dictionaryLimit = 1 << totalBitsToRead;
      }
      final String dataToWrite = dictionary[code];
      final int len = dataToWrite.length;
      for (int i = 0; i < len; i++) {
        final int colorIndex = dataToWrite.codeUnitAt(i);
        if (transparentColorIndex != colorIndex) {
          final int color = colorTable[colorIndex];
          data[writeIndex++] = color & 0xFF;
          data[writeIndex++] = (color >> 8) & 0xFF;
          data[writeIndex++] = (color >> 16) & 0xFF;
          data[writeIndex++] = (color >> 24) & 0xFF;
        }
        else {
          if (_priorFrame != null && _priorFrame.disposalMethod == 1) {
            data[writeIndex] = _priorFrame.data[writeIndex];
            writeIndex++;
            data[writeIndex] = _priorFrame.data[writeIndex];
            writeIndex++;
            data[writeIndex] = _priorFrame.data[writeIndex];
            writeIndex++;
            data[writeIndex] = _priorFrame.data[writeIndex];
            writeIndex++;
          } else {
            data[writeIndex++] = 0;
            data[writeIndex++] = 0;
            data[writeIndex++] = 0;
            data[writeIndex++] = 0;
          }
        }
      }
    }
    return data;
  }
  static void _clearDictionary(List<String> dict, int codeSize) {
    dict.clear();
    for (int i = 0; i < codeSize; i++) {
      dict.add(String.fromCharCode(i));
    }
    // Clear code.
    dict.add('');
    // Stop code.
    dict.add(null);
  }
}

class _GifFrame {
  _GifFrame(this.width, this.height, this.data, this.disposalMethod);
  final Uint8ClampedList data;
  final int width;
  final int height;
  final int disposalMethod;
  html.ImageData _imageData;

  html.ImageData readImageData() {
    return _imageData ??= html.ImageData(data, width, height);
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
//              Image.asset('lib/animated_images/giphy1.gif'),
//              Text('AAA'),
//              Image.asset('lib/animated_images/animated_flutter_lgtm.gif'),
//              Text('BBB'),
//              Image.asset('lib/animated_images/giphy2.gif'),
//              Text('CCC'),
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
