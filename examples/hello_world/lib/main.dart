// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection' as collection;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:ui' as engine;
import 'path2.dart' as path2;
import 'engine2.dart' as engine;

void main() => runApp(MyApp());

class MyPainter extends CustomPainter {
  MyPainter(this.startAngle, this.endAngle, this.rotation);

  final double startAngle,endAngle,rotation;

  @override
  void paint(Canvas canvas, Size size) {
    const double rx = 100;
    const double ry = 50;
    const double cx = 150;
    const double cy  = 100;

    double startRad = startAngle *math.pi / 180.0;
    double endRad = endAngle*math.pi / 180.0;

    final double startX = cx + (rx * math.cos(startRad));
    final double startY = cy + (ry * math.sin(startRad));
    final double endX = cx + (rx * math.cos(endRad));
    final double endY = cy + (ry * math.sin(endRad));

    final bool clockwise = endAngle > startAngle;
    final bool largeArc = (endAngle - startAngle).abs() > 180.0;
    final Path path = Path()
      ..moveTo(cx, cy)
      //..quadraticBezierTo(cx + 100, cy + 50, cx + 200, cy - 20);
      ..arcToPoint(Offset(endX, endY), radius: const Radius.elliptical(rx, ry),
          clockwise: clockwise, largeArc: largeArc, rotation: rotation);

    final path2.Path newPath = path2.Path()
//      ..moveTo(cx, cy)
//      ..quadraticBezierTo(cx + 100, cy + 50, cx + 200, cy - 20);
      ..moveTo(startX, startY)
      ..arcToPoint(Offset(endX, endY), radius: const Radius.elliptical(rx, ry),
          clockwise: clockwise, largeArc: largeArc, rotation: rotation);


    canvas.drawPath(path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.white
    );
    canvas.drawRect(const Rect.fromLTRB(cx - rx, cy - ry, cx + rx, cy + ry),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color=Colors.black
    );


    PathMetric2 metric = PathMetric2._(newPath, false);
    final List<_PathSegment> segments = metric._segments;
    final Paint redFill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red;
    final Paint greenFill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.green;
    for (int i = 0; i < segments.length; i++) {
      final _PathSegment seg = segments[i];
      canvas.drawCircle(Offset(seg.points[0], seg.points[1]), 2.0, redFill);

      if (seg.segmentType == engine.PathCommandTypes.lineTo) {
        canvas.drawCircle(Offset(seg.points[0], seg.points[1]), 2.0, redFill);
        canvas.drawCircle(Offset(seg.points[2], seg.points[3]), 2.0, redFill);
      }
      if (seg.segmentType == engine.PathCommandTypes.quadraticCurveTo) {
        canvas.drawCircle(Offset(seg.points[0], seg.points[1]), 2.0, greenFill);
        canvas.drawCircle(Offset(seg.points[4], seg.points[5]), 2.0, greenFill);
      }
    }

    Path path1 = Path();
    {
      const double rx = 100;
      const double ry = 50;
      const double cx = 150;
      const double cy = 100;
      const double startAngle = 0.0;
      const double endAngle = 270.0;
      double startRad = startAngle * math.pi / 180.0;
      double endRad = endAngle * math.pi / 180.0;

      final double startX = cx + (rx * math.cos(startRad));
      final double startY = cy + (ry * math.sin(startRad));
      final double endX = cx + (rx * math.cos(endRad));
      final double endY = cy + (ry * math.sin(endRad));

      const bool clockwise = endAngle > startAngle;
      final bool largeArc = (endAngle - startAngle).abs() > 180.0;
      path1 = Path()
//        ..moveTo(startX, startY)
//        ..arcToPoint(
//            Offset(endX, endY), radius: const Radius.elliptical(rx, ry),
//            clockwise: clockwise, largeArc: largeArc, rotation: 0.0);
          ..addRRect(RRect.fromLTRBR(20, 30, 220, 130, Radius.elliptical(8, 4)));

//    path.arcToPoint(Offset(endX, endY), radius: const Radius.elliptical(rx, ry),
//          clockwise: clockwise, largeArc: largeArc, rotation: rotation);

      final List<double> lengths = computeLengths(path1);
      StringBuffer sb = StringBuffer();
      if (lengths == null || lengths.isEmpty) {
        sb.writeln('No length returned');
      }
      for (int i = 0; i < lengths.length; i++) {
        sb.writeln('$i: ${lengths[i]}');
      }
      final engine.ParagraphStyle paraStyle = engine.ParagraphStyle(
          fontSize: 40.0);
      final engine.ParagraphBuilder paraBuilder = engine.ParagraphBuilder(
          paraStyle);
      paraBuilder.pushStyle(engine.TextStyle(color: Colors.black));
      paraBuilder.addText(sb.toString());
      final engine.Paragraph paragraph = paraBuilder.build();
      paragraph.layout(const engine.ParagraphConstraints(width: 600.0));
      canvas.drawParagraph(paragraph, const Offset(20, 0));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

List<double> computeLengths(Path path) {
  engine.PathMetrics pathMetrics = path.computeMetrics();
  final List<double> lengths = <double>[];
  for (engine.PathMetric metric in pathMetrics) {
    lengths.add(metric.length);
  }
  return lengths;
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double _startAngle = 0;
  double _endAngle = 280;
  double _rotation = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(padding: const EdgeInsets.only(left: 20.0, right: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(color: Colors.blueGrey.withAlpha(0x40), width: 800.0, height: 800.0,
                child: CustomPaint(painter: MyPainter(_startAngle, _endAngle, _rotation)),
              ),
              Slider(value: _startAngle, min: 0.0, max: 360.0,
                label: 'start',
                onChanged: (double value) {
                  setState(() {
                    _startAngle = value;
                  });
                },
              ),
              Slider(value: _endAngle, min: 0.0, max: 360.0,
                label: 'end',
                onChanged: (double value) {
                  setState(() {
                    _endAngle = value;
                  });
                },
              ),
              Slider(value: _rotation, min: 0.0, max: 360.0,
                label: 'rotate',
                onChanged: (double value) {
                  setState(() {
                    _rotation = value;
                  });
                },
              ),

            ],
          ),
        ),
      ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}


/// An iterable collection of [PathMetric] objects describing a [Path].
///
/// A [PathMetrics] object is created by using the [Path.computeMetrics] method,
/// and represents the path as it stood at the time of the call. Subsequent
/// modifications of the path do not affect the [PathMetrics] object.
///
/// Each path metric corresponds to a segment, or contour, of a path.
///
/// For example, a path consisting of a [Path.lineTo], a [Path.moveTo], and
/// another [Path.lineTo] will contain two contours and thus be represented by
/// two [PathMetric] objects.
///
/// When iterating across a [PathMetrics]' contours, the [PathMetric] objects
/// are only valid until the next one is obtained.
class PathMetrics2 extends collection.IterableBase<PathMetric2> {
  PathMetrics2._(path2.Path path, bool forceClosed)
      : _iterator = PathMetricIterator2._(PathMetric2._(path, forceClosed));

  final Iterator<PathMetric2> _iterator;

  @override
  Iterator<PathMetric2> get iterator => _iterator;
}

/// Tracks iteration from one segment of a path to the next for measurement.
class PathMetricIterator2 implements Iterator<PathMetric2> {
  PathMetricIterator2._(this._pathMetric);

  PathMetric2 _pathMetric;
  bool _firstTime = true;

  @override
  PathMetric2 get current => _firstTime ? null : _pathMetric;

  @override
  bool moveNext() {
    // PathMetric isn't a normal iterable - it's already initialized to its
    // first Path.  Should only call _moveNext when done with the first one.
    if (_firstTime == true) {
      _firstTime = false;
      return true;
    } else if (_pathMetric?._moveNext() == true) {
      return true;
    }
    _pathMetric = null;
    return false;
  }
}

const int _kMaxTValue = 0x3FFFFFFF;
const double _fTolerance = 0.5;

/// Utilities for measuring a [Path] and extracting subpaths.
///
/// Iterate over the object returned by [Path.computeMetrics] to obtain
/// [PathMetric] objects.
///
/// Once created, metrics will only be valid while the iterator is at the given
/// contour. When the next contour's [PathMetric] is obtained, this object
/// becomes invalid.
///
/// Implementation is based on
/// https://github.com/google/skia/blob/master/src/core/SkContourMeasure.cpp
/// to maintain consistency with native platforms.
class PathMetric2 {
  final path2.Path _path;
  final bool _forceClosed;

  // If the contour ends with a call to [Path.close] (which may
  // have been implied when using [Path.addRect])
  bool _isClosed;
  // Iterator index into [Path.subPaths]
  int _subPathIndex = 0;
  List<_PathSegment> _segments;

  /// Create a new empty [Path] object.
  PathMetric2._(this._path, this._forceClosed) {
    _buildSegments();
  }

  /// Return the total length of the current contour.
  double get length => throw UnimplementedError();

  /// Computes the position of hte current contour at the given offset, and the
  /// angle of the path at that point.
  ///
  /// For example, calling this method with a distance of 1.41 for a line from
  /// 0.0,0.0 to 2.0,2.0 would give a point 1.0,1.0 and the angle 45 degrees
  /// (but in radians).
  ///
  /// Returns null if the contour has zero [length].
  ///
  /// The distance is clamped to the [length] of the current contour.
  Tangent2 getTangentForOffset(double distance) {
    final Float32List posTan = _getPosTan(distance);
    // first entry == 0 indicates that Skia returned false
    if (posTan[0] == 0.0) {
      return null;
    } else {
      return Tangent2(
          Offset(posTan[1], posTan[2]), Offset(posTan[3], posTan[4]));
    }
  }

  Float32List _getPosTan(double distance) => throw UnimplementedError();

  /// Given a start and stop distance, return the intervening segment(s).
  ///
  /// `start` and `end` are pinned to legal values (0..[length])
  /// Returns null if the segment is 0 length or `start` > `stop`.
  /// Begin the segment with a moveTo if `startWithMoveTo` is true.
  Path extractPath(double start, double end, {bool startWithMoveTo = true}) =>
      throw UnimplementedError();

  /// Whether the contour is closed.
  ///
  /// Returns true if the contour ends with a call to [Path.close] (which may
  /// have been implied when using [Path.addRect]) or if `forceClosed` was
  /// specified as true in the call to [Path.computeMetrics].  Returns false
  /// otherwise.
  bool get isClosed {
    return _isClosed;
  }

  // Move to the next contour in the path.
  //
  // A path can have a next contour if [Path.moveTo] was called after drawing
  // began. Return true if one exists, or false.
  //
  // This is not exactly congruent with a regular [Iterator.moveNext].
  // Typically, [Iterator.moveNext] should be called before accessing the
  // [Iterator.current]. In this case, the [PathMetric] is valid before
  // calling `_moveNext` - `_moveNext` should be called after the first
  // iteration is done instead of before.
  bool _moveNext() {
    if (_subPathIndex == (_path.subpaths.length - 1)) {
      return false;
    }
    ++_subPathIndex;
    _buildSegments();
    return true;
  }

  void _buildSegments() {
    _segments = <_PathSegment>[];
    _isClosed = _forceClosed;
    double distance = 0.0;
    int pointIndex = -1;
    bool haveSeenMoveTo = false;
    bool haveSeenClose = false;
    final engine.Subpath subpath = _path.subpaths[_subPathIndex];
    final List<engine.PathCommand> commands = subpath.commands;
    double currentX = 0.0, currentY = 0.0;
    for (engine.PathCommand command in commands) {
      switch (command.type) {
        case engine.PathCommandTypes.moveTo:
          final engine.MoveTo moveTo = command;
          currentX = moveTo.x;
          currentY = moveTo.y;
          _isClosed = true;
          haveSeenMoveTo = true;
          break;
        case engine.PathCommandTypes.lineTo:
          assert(haveSeenMoveTo);
          final engine.LineTo lineTo = command;
          final double dx = currentX - lineTo.x;
          final double dy = currentY - lineTo.y;
          final double prevDistance = distance;
          distance += math.sqrt(dx * dx + dy * dy);
          // As we accumulate distance, we have to check that the result of +=
          // actually made it larger, since a very small delta might be > 0, but
          // still have no effect on distance (if distance >>> delta).
          if (distance > prevDistance) {
            _segments.add(_PathSegment(engine.PathCommandTypes.lineTo, distance,
                [currentX, currentY, lineTo.x, lineTo.y]));
          }
          break;
        case engine.PathCommandTypes.cubicCurveTo:
          assert(haveSeenMoveTo);
          final engine.CubicCurveTo curve = command;
          // Compute cubic curve distance.
          distance = _computeCubicSegments(
              currentX, currentY, curve.x1, curve.y1, curve.x2, curve.y2, curve.x3, curve.y3, distance, 0, _kMaxTValue);
          break;
        case engine.PathCommandTypes.quadraticCurveTo:
          assert(haveSeenMoveTo);
          final engine.QuadraticCurveTo quadraticCurveTo = command;
          // Compute quad curve distance.
          distance = _computeQuadSegments(
              currentX,
              currentY,
              quadraticCurveTo.x1,
              quadraticCurveTo.y1,
              quadraticCurveTo.x2,
              quadraticCurveTo.y2,
              distance,
              0,
              _kMaxTValue);
          break;
        case engine.PathCommandTypes.close:
          haveSeenClose = true;
          break;
        case engine.PathCommandTypes.ellipse:
          final engine.Ellipse ellipse = command;
          distance = _computeEllipseSegments(currentX, currentY, distance,
              ellipse.x, ellipse.y, ellipse.startAngle, ellipse.endAngle,
              ellipse.rotation,
              ellipse.radiusX, ellipse.radiusY, ellipse.anticlockwise);
          _isClosed = true;
          break;
        case engine.PathCommandTypes.rRect:
          final engine.RRectCommand rrectCommand = command;
          final RRect rrect = rrectCommand.rrect;
          _isClosed = true;
          break;
        case engine.PathCommandTypes.rect:
          final engine.RectCommand rectCommand = command;
          _isClosed = true;
          break;
        default:
          throw UnimplementedError('Unknown path command $command');
      }
    }
  }

  static bool _tspanBigEnough(int tSpan) => (tSpan >> 10) != 0;

  static bool _cubicTooCurvy(
      double x0, double y0, double x1, double y1, double x2, double y2,
      double x3, double y3) {
    // Measure distance from start-end line at 1/3 and 2/3rds to control
    // points. If distance is less than _fTolerance we should continue
    // subdividing curve. Uses approx distance for speed.
    //
    // p1 = point 1/3rd between start,end points.
    final double p1x = (x0 * 2 / 3) + (x3 / 3);
    final double p1y = (y0 * 2 / 3) + (y3 / 3);
    if ((p1x - x1).abs() > _fTolerance) {
      return true;
    }
    if ((p1y - y1).abs() > _fTolerance) {
      return true;
    }
    // p2 = point 2/3rd between start,end points.
    final double p2x = (x0 / 3) + (x3 * 2 / 3);
    final double p2y = (y0 / 3) + (y3 * 2 / 3);
    if ((p2x - x2).abs() > _fTolerance) {
      return true;
    }
    if ((p2y - y2).abs() > _fTolerance) {
      return true;
    }
    return false;
  }

  // Recursively subdivides cubic and adds segments.
  double _computeCubicSegments(double x0, double y0, double x1, double y1,
      double x2, double y2, double x3, double y3, double distance, int tMin, int tMax) {
    if (_tspanBigEnough(tMax - tMin) &&
        _cubicTooCurvy(x0, y0, x1, y1, x2, y2, x3, y3)) {
      // Chop cubic into two halves (De Cateljau's algorithm)
      // See https://en.wikipedia.org/wiki/De_Casteljau%27s_algorithm
      final double abX = (x0 + x1) / 2;
      final double abY = (y0 + y1) / 2;
      final double bcX = (x1 + x2) / 2;
      final double bcY = (y1 + y2) / 2;
      final double cdX = (x2 + x3) / 2;
      final double cdY = (y2 + y3) / 2;
      final double abcX = (abX + bcX) / 2;
      final double abcY = (abY + bcY) / 2;
      final double bcdX = (bcX + cdX) / 2;
      final double bcdY = (bcY + cdY) / 2;
      final double abcdX = (abcX + bcdX) / 2;
      final double abcdY = (abcY + bcdY) / 2;
      final int tHalf = (tMin + tMax) >> 1;
      distance =
          _computeCubicSegments(x0, y0, abX, abY, abcX, abcY, abcdX, abcdY, distance, tMin, tHalf);
      distance =
          _computeCubicSegments(abcdX, abcdY, bcdX, bcdY, cdX, cdY, x3, y3, distance, tHalf, tMax);
    } else {
      final double dx = x0 - x3;
      final double dy = y0 - y3;
      final double startToEndDistance = math.sqrt(dx * dx + dy * dy);
      final double prevDistance = distance;
      distance += startToEndDistance;
      if (distance > prevDistance) {
        _segments.add(_PathSegment(engine.PathCommandTypes.cubicCurveTo,
            distance, <double>[x0, y0, x1, y1, x2, y2, x3, y3]));
      }
    }
    return distance;
  }

  static bool _quadTooCurvy(
      double x0, double y0, double x1, double y1, double x2, double y2) {
    // (a/4 + b/2 + c/4) - (a/2 + c/2)  =  -a/4 + b/2 - c/4
    final double dx = (x1 / 2) - (x0 + x2) / 4;
    if (dx.abs() > _fTolerance) {
      return true;
    }
    final double dy = (y1 / 2) - (y0 + y2) / 4;
    if (dy.abs() > _fTolerance) {
      return true;
    }
    return false;
  }

  double _computeQuadSegments(double x0, double y0, double x1, double y1,
      double x2, double y2, double distance, int tMin, int tMax) {
    if (_tspanBigEnough(tMax - tMin) &&
        _quadTooCurvy(x0, y0, x1, y1, x2, y2)) {
      final double p01x = (x0 + x1) / 2;
      final double p01y = (y0 + y1) / 2;
      final double p12x = (x1 + x2) / 2;
      final double p12y = (y1 + y2) / 2;
      final double p012x = (p01x + p12x) / 2;
      final double p012y = (p01y + p12y) / 2;
      final int tHalf = (tMin + tMax) >> 1;
      distance = _computeQuadSegments(
          x0, y0, p01x, p01y, p012x, p012y, distance, tMin, tHalf);
      distance = _computeQuadSegments(
          p012x, p012y, p12x, p12y, x2, y2, distance, tMin, tHalf);
    } else {
      final double dx = x0 - x2;
      final double dy = y0 - y2;
      final double startToEndDistance = math.sqrt(dx * dx + dy * dy);
      final double prevDistance = distance;
      distance += startToEndDistance;
      if (distance > prevDistance) {
        _segments.add(_PathSegment(engine.PathCommandTypes.quadraticCurveTo,
            distance, <double>[x0, y0, x1, y1, x2, y2]));
      }
    }
    return distance;
  }

  // Create segments by converting arc to cubics.
  // See http://www.w3.org/TR/SVG/implnote.html#ArcConversionEndpointToCenter.
  double _computeEllipseSegments(double startX, double startY,
      double distance, double endX, double endY,
      double startAngle, double endAngle,
      double rotation, double radiusX, double radiusY, bool anticlockwise) {
    // Convert arc to conics.
    const int _kMaxConicsForArc = 5;

    // Check for http://www.w3.org/TR/SVG/implnote.html#ArcOutOfRangeParameters
    // Treat as line segment from start to end if arc has zero radii.
    // If start and end point are the same treat as zero length path.
    if ((radiusX == 0 || radiusY == 0) ||
        (startX == endX && startY == endY)) {
      return distance;
    }

    final double rxAbs = radiusX.abs();
    final double ryAbs = radiusY.abs();

    final double midPointDistX = (startX - endX) / 2;
    final double midPointDistY = (startY - endY) / 2;

    // Rotate midpoint back by -startAngle.
    double cosAngle = math.cos(-startAngle);
    double sinAngle = math.sin(-startAngle);
    final double midPointX = midPointDistX * cosAngle - midPointDistY * sinAngle;
    final double midPointY = midPointDistX * sinAngle + midPointDistY * cosAngle;

    final double rxSquare = rxAbs * rxAbs;
    final double rySquare = ryAbs * ryAbs;
    final double endXSquare = midPointX * midPointX;
    final double endYSquare = midPointY * midPointY;

    // Scale radii if it is not big enough to draw arc.
    // http://www.w3.org/TR/SVG/implnote.html#ArcCorrectionOutOfRangeRadii
    final double radiiScale = endXSquare / rxSquare + endYSquare / rySquare;
    bool doScale = (radiiScale > 1.0);
    final double rx = doScale ? rxAbs * math.sqrt(radiiScale) : rxAbs;
    final double ry = doScale ? ryAbs * math.sqrt(radiiScale) : ryAbs;

    // Now take start and end point and reverse transform by scaling down
    // by rx,ry and rotating -startAngle.
    final double scaledStartX = (startX / rx);
    final double scaledStartY = (startY / ry);
    final double point1X = scaledStartX * cosAngle - scaledStartY * sinAngle;
    final double point1Y = scaledStartX * sinAngle + scaledStartY * cosAngle;
    final double scaledEndX = (endX / rx);
    final double scaledEndY = (endY / ry);
    final double point2X = scaledEndX * cosAngle - scaledEndY * sinAngle;
    final double point2Y = scaledEndX * sinAngle + scaledEndY * cosAngle;

    double deltaX = point2X - point1X;
    double deltaY = point2Y - point1Y;

    final double d = deltaX * deltaX + deltaY * deltaY;
    double scaleFactor = math.sqrt(math.max(1 /d - 0.25, 0.0));

    bool isLargeArc = (endAngle - startAngle).abs() > math.pi;
    if (isLargeArc == anticlockwise) {
      scaleFactor = -scaleFactor;
    }
    deltaX *= scaleFactor;
    deltaY *= scaleFactor;

    double centerPointX = (point1X + point2X) / 2;
    double centerPointY = (point1Y + point2Y) / 2;

    centerPointX -= deltaY;
    centerPointY += deltaX;

    final double theta1 = math.atan2(point1Y - centerPointY, point1X - centerPointX);
    final double theta2 = math.atan2(point2Y - centerPointY, point2X - centerPointX);

    double thetaArc = theta2 - theta1;
    if (thetaArc < 0 && anticlockwise) {
      thetaArc += math.pi * 2;
    } else if (thetaArc > 0 && !anticlockwise) {
      thetaArc -= math.pi * 2;
    }

    // Add 0.01f aince atan2 implementations are sometimes not exact enough.
    // This reduces number of segments.
    int numSegments = (thetaArc / ((math.pi / 2.0) + 0.01)).abs().ceil();

    double x0 = startX;
    double y0 = startY;
    for (int segmentIndex = 0; segmentIndex < numSegments; segmentIndex++) {
      final double startTheta = theta1 + (segmentIndex * thetaArc / numSegments);
      final double endTheta = theta1 + ((segmentIndex + 1 ) * thetaArc / numSegments);
      final double t = (8.0 / 6.0) * math.tan(0.25 * (endTheta - startTheta));
      if (!t.isFinite) {
        return distance;
      }
      final double sinStartTheta = math.sin(startTheta);
      final double cosStartTheta = math.cos(startTheta);
      final double sinEndTheta = math.sin(endTheta);
      final double cosEndTheta = math.cos(endTheta);

      // Compute cubic segment start, control point and end (target).
      final double p1x = (cosStartTheta - t * sinStartTheta) + centerPointX;
      final double p1y = (sinStartTheta + t * cosStartTheta) + centerPointY;
      final double targetPointX = cosEndTheta + centerPointX;
      final double targetPointY = sinEndTheta + centerPointY;
      final double p2x = targetPointX + (t * sinEndTheta);
      final double p2y = targetPointY + (-t * cosEndTheta);

      distance = _computeCubicSegments(x0, y0, p1x, p1y, p2x, p2y, targetPointX, targetPointY, distance, 0, _kMaxTValue);
    }
    return distance;
  }

  @override
  String toString() => 'PathMetric';
}

class _PathSegment {
  _PathSegment(this.segmentType, this.distance, this.points);

  final int segmentType;
  final double distance;
  final List<double> points;
}

/// The geometric description of a tangent: the angle at a point.
///
/// See also:
///  * [PathMetric.getTangentForOffset], which returns the tangent of an offset
///    along a path.
class Tangent2 {
  /// Creates a [Tangent] with the given values.
  ///
  /// The arguments must not be null.
  const Tangent2(this.position, this.vector)
      : assert(position != null),
        assert(vector != null);

  /// Creates a [Tangent] based on the angle rather than the vector.
  ///
  /// The [vector] is computed to be the unit vector at the given angle,
  /// interpreted as clockwise radians from the x axis.
  factory Tangent2.fromAngle(Offset position, double angle) {
    return Tangent2(position, Offset(math.cos(angle), math.sin(angle)));
  }

  /// Position of the tangent.
  ///
  /// When used with [PathMetric.getTangentForOffset], this represents the
  /// precise position that the given offset along the path corresponds to.
  final Offset position;

  /// The vector of the curve at [position].
  ///
  /// When used with [PathMetric.getTangentForOffset], this is the vector of the
  /// curve that is at the given offset along the path (i.e. the direction of
  /// the curve at [position]).
  final Offset vector;

  /// The direction of the curve at [position].
  ///
  /// When used with [PathMetric.getTangentForOffset], this is the angle of the
  /// curve that is the given offset along the path (i.e. the direction of the
  /// curve at [position]).
  ///
  /// This value is in radians, with 0.0 meaning pointing along the x axis in
  /// the positive x-axis direction, positive numbers pointing downward toward
  /// the negative y-axis, i.e. in a clockwise direction, and negative numbers
  /// pointing upward toward the positive y-axis, i.e. in a counter-clockwise
  /// direction.
  // flip the sign to be consistent with [Path.arcTo]'s `sweepAngle`
  double get angle => -math.atan2(vector.dy, vector.dx);
}
