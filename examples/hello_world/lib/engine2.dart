import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

bool assertionsEnabled = true;

class Subpath {
  double startX = 0.0;
  double startY = 0.0;
  double currentX = 0.0;
  double currentY = 0.0;

  final List<PathCommand> commands;

  Subpath(this.startX, this.startY) : commands = <PathCommand>[];

  Subpath shift(ui.Offset offset) {
    final Subpath result = Subpath(startX + offset.dx, startY + offset.dy)
      ..currentX = currentX + offset.dx
      ..currentY = currentY + offset.dy;

    for (final PathCommand command in commands) {
      result.commands.add(command.shifted(offset));
    }

    return result;
  }

  List<dynamic> serializeToCssPaint() {
    final List<dynamic> serialization = <dynamic>[];
    for (int i = 0; i < commands.length; i++) {
      serialization.add(commands[i].serializeToCssPaint());
    }
    return serialization;
  }

  @override
  String toString() {
    if (assertionsEnabled) {
      return 'Subpath(${commands.join(', ')})';
    } else {
      return super.toString();
    }
  }
}

/// ! Houdini implementation relies on indices here. Keep in sync.
class PathCommandTypes {
  static const int moveTo = 0;
  static const int lineTo = 1;
  static const int ellipse = 2;
  static const int close = 3;
  static const int quadraticCurveTo = 4;
  static const int cubicCurveTo = 5;
  static const int rect = 6;
  static const int rRect = 7;
}

abstract class PathCommand {
  final int type;
  const PathCommand(this.type);

  PathCommand shifted(ui.Offset offset);

  List<dynamic> serializeToCssPaint();

  /// Transform the command and add to targetPath.
  void transform(Float64List matrix4, ui.Path targetPath);

  /// Helper method for implementing transforms.
  static ui.Offset _transformOffset(double x, double y, Float64List matrix4) =>
      ui.Offset((matrix4[0] * x) + (matrix4[4] * y) + matrix4[12],
          (matrix4[1] * x) + (matrix4[5] * y) + matrix4[13]);
}

class MoveTo extends PathCommand {
  final double x;
  final double y;

  const MoveTo(this.x, this.y) : super(PathCommandTypes.moveTo);

  @override
  MoveTo shifted(ui.Offset offset) {
    return MoveTo(x + offset.dx, y + offset.dy);
  }

  @override
  List<dynamic> serializeToCssPaint() {
    return <dynamic>[1, x, y];
  }

  @override
  void transform(Float64List matrix4, ui.Path targetPath) {
    final ui.Offset offset = PathCommand._transformOffset(x, y, matrix4);
    targetPath.moveTo(offset.dx, offset.dy);
  }

  @override
  String toString() {
    if (assertionsEnabled) {
      return 'MoveTo($x, $y)';
    } else {
      return super.toString();
    }
  }
}

class LineTo extends PathCommand {
  final double x;
  final double y;

  const LineTo(this.x, this.y) : super(PathCommandTypes.lineTo);

  @override
  LineTo shifted(ui.Offset offset) {
    return LineTo(x + offset.dx, y + offset.dy);
  }

  @override
  List<dynamic> serializeToCssPaint() {
    return <dynamic>[2, x, y];
  }

  @override
  void transform(Float64List matrix4, ui.Path targetPath) {
    final ui.Offset offset = PathCommand._transformOffset(x, y, matrix4);
    targetPath.lineTo(offset.dx, offset.dy);
  }

  @override
  String toString() {
    if (assertionsEnabled) {
      return 'LineTo($x, $y)';
    } else {
      return super.toString();
    }
  }
}

class Ellipse extends PathCommand {
  final double x;
  final double y;
  final double radiusX;
  final double radiusY;
  final double rotation;
  final double startAngle;
  final double endAngle;
  final bool anticlockwise;

  const Ellipse(this.x, this.y, this.radiusX, this.radiusY, this.rotation,
      this.startAngle, this.endAngle, this.anticlockwise)
      : super(PathCommandTypes.ellipse);

  @override
  Ellipse shifted(ui.Offset offset) {
    return Ellipse(x + offset.dx, y + offset.dy, radiusX, radiusY, rotation,
        startAngle, endAngle, anticlockwise);
  }

  @override
  List<dynamic> serializeToCssPaint() {
    return <dynamic>[
      3,
      x,
      y,
      radiusX,
      radiusY,
      rotation,
      startAngle,
      endAngle,
      anticlockwise,
    ];
  }

  @override
  void transform(Float64List matrix4, ui.Path targetPath) {
    final ui.Path bezierPath = ui.Path();
    _drawArcWithBezier(x, y, radiusX, radiusY, rotation,
        startAngle,
        anticlockwise ? startAngle - endAngle : endAngle - startAngle,
        matrix4, bezierPath);
    targetPath.addPath(bezierPath, ui.Offset.zero, matrix4: matrix4);
  }

  void _drawArcWithBezier(double centerX, double centerY,
      double radiusX, double radiusY, double rotation, double startAngle,
      double sweep, Float64List matrix4, ui.Path targetPath) {
    double ratio = sweep.abs() / (math.pi / 2.0);
    if ((1.0 - ratio).abs() < 0.0000001) {
      ratio = 1.0;
    }
    final int segments = math.max(ratio.ceil(), 1);
    final double anglePerSegment = sweep / segments;
    double angle = startAngle;
    for (int segment = 0; segment < segments; segment++) {
      _drawArcSegment(targetPath, centerX, centerY, radiusX, radiusY, rotation,
          angle, anglePerSegment, segment == 0, matrix4);
      angle += anglePerSegment;
    }
  }

  void _drawArcSegment(ui.Path path, double centerX, double centerY,
      double radiusX, double radiusY, double rotation, double startAngle,
      double sweep, bool startPath, Float64List matrix4) {
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
  String toString() {
    if (assertionsEnabled) {
      return 'Ellipse($x, $y, $radiusX, $radiusY)';
    } else {
      return super.toString();
    }
  }
}

class QuadraticCurveTo extends PathCommand {
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const QuadraticCurveTo(this.x1, this.y1, this.x2, this.y2)
      : super(PathCommandTypes.quadraticCurveTo);

  @override
  QuadraticCurveTo shifted(ui.Offset offset) {
    return QuadraticCurveTo(
        x1 + offset.dx, y1 + offset.dy, x2 + offset.dx, y2 + offset.dy);
  }

  @override
  List<dynamic> serializeToCssPaint() {
    return <dynamic>[4, x1, y1, x2, y2];
  }

  @override
  void transform(Float64List matrix4, ui.Path targetPath) {
    final double m0 = matrix4[0];
    final double m1 = matrix4[1];
    final double m4 = matrix4[4];
    final double m5 = matrix4[5];
    final double m12 = matrix4[12];
    final double m13 = matrix4[13];
    final double transformedX1 = (m0 * x1) + (m4 * y1) + m12;
    final double transformedY1 = (m1 * x1) + (m5 * y1) + m13;
    final double transformedX2 = (m0 * x2) + (m4 * y2) + m12;
    final double transformedY2 = (m1 * x2) + (m5 * y2) + m13;
    targetPath.quadraticBezierTo(transformedX1, transformedY1,
        transformedX2, transformedY2);
  }

  @override
  String toString() {
    if (assertionsEnabled) {
      return 'QuadraticCurveTo($x1, $y1, $x2, $y2)';
    } else {
      return super.toString();
    }
  }
}

class CubicCurveTo extends PathCommand {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x3;
  final double y3;

  const CubicCurveTo(this.x1, this.y1, this.x2, this.y2, this.x3, this.y3)
      : super(PathCommandTypes.cubicCurveTo);

  @override
  CubicCurveTo shifted(ui.Offset offset) {
    return CubicCurveTo(x1 + offset.dx, y1 + offset.dy, x2 + offset.dx,
        y2 + offset.dy, x3 + offset.dx, y3 + offset.dy);
  }

  @override
  List<dynamic> serializeToCssPaint() {
    return <dynamic>[5, x1, y1, x2, y2, x3, y3];
  }

  @override
  void transform(Float64List matrix4, ui.Path targetPath) {
    final double s0 = matrix4[0];
    final double s1 = matrix4[1];
    final double s4 = matrix4[4];
    final double s5 = matrix4[5];
    final double s12 = matrix4[12];
    final double s13 = matrix4[13];
    final double transformedX1 = (s0 * x1) + (s4 * y1) + s12;
    final double transformedY1 = (s1 * x1) + (s5 * y1) + s13;
    final double transformedX2 = (s0 * x2) + (s4 * y2) + s12;
    final double transformedY2 = (s1 * x2) + (s5 * y2) + s13;
    final double transformedX3 = (s0 * x3) + (s4 * y3) + s12;
    final double transformedY3 = (s1 * x3) + (s5 * y3) + s13;
    targetPath.cubicTo(transformedX1, transformedY1,
        transformedX2, transformedY2, transformedX3, transformedY3);
  }

  @override
  String toString() {
    if (assertionsEnabled) {
      return 'CubicCurveTo($x1, $y1, $x2, $y2, $x3, $y3)';
    } else {
      return super.toString();
    }
  }
}

class RectCommand extends PathCommand {
  final double x;
  final double y;
  final double width;
  final double height;

  const RectCommand(this.x, this.y, this.width, this.height)
      : super(PathCommandTypes.rect);

  @override
  RectCommand shifted(ui.Offset offset) {
    return RectCommand(x + offset.dx, y + offset.dy, width, height);
  }

  @override
  void transform(Float64List matrix4, ui.Path targetPath) {
    final double s0 = matrix4[0];
    final double s1 = matrix4[1];
    final double s4 = matrix4[4];
    final double s5 = matrix4[5];
    final double s12 = matrix4[12];
    final double s13 = matrix4[13];
    final double transformedX1 = (s0 * x) + (s4 * y) + s12;
    final double transformedY1 = (s1 * x) + (s5 * y) + s13;
    final double x2 = x + width;
    final double y2 = y + height;
    final double transformedX2 = (s0 * x2) + (s4 * y) + s12;
    final double transformedY2 = (s1 * x2) + (s5 * y) + s13;
    final double transformedX3 = (s0 * x2) + (s4 * y2) + s12;
    final double transformedY3 = (s1 * x2) + (s5 * y2) + s13;
    final double transformedX4 = (s0 * x) + (s4 * y2) + s12;
    final double transformedY4 = (s1 * x) + (s5 * y2) + s13;
    if (transformedY1 == transformedY2 && transformedY3 == transformedY4 &&
        transformedX1 == transformedX4 && transformedX2 == transformedX3) {
      // It is still a rectangle.
      targetPath.addRect(ui.Rect.fromLTRB(transformedX1, transformedY1,
          transformedX3, transformedY3));
    } else {
      targetPath.moveTo(transformedX1, transformedY1);
      targetPath.lineTo(transformedX2, transformedY2);
      targetPath.lineTo(transformedX3, transformedY3);
      targetPath.lineTo(transformedX4, transformedY4);
      targetPath.close();
    }
  }

  @override
  List<dynamic> serializeToCssPaint() {
    return <dynamic>[6, x, y, width, height];
  }

  @override
  String toString() {
    if (assertionsEnabled) {
      return 'Rect($x, $y, $width, $height)';
    } else {
      return super.toString();
    }
  }
}

class RRectCommand extends PathCommand {
  final ui.RRect rrect;

  const RRectCommand(this.rrect) : super(PathCommandTypes.rRect);

  @override
  RRectCommand shifted(ui.Offset offset) {
    return RRectCommand(rrect.shift(offset));
  }

  @override
  void transform(Float64List matrix4, ui.Path targetPath) {
    throw UnimplementedError();
  }

  @override
  String toString() {
    if (assertionsEnabled) {
      return '$rrect';
    } else {
      return super.toString();
    }
  }

  @override
  List serializeToCssPaint() {
    // TODO: implement serializeToCssPaint
    return null;
  }
}

class CloseCommand extends PathCommand {
  const CloseCommand() : super(PathCommandTypes.close);

  @override
  CloseCommand shifted(ui.Offset offset) {
    return this;
  }

  @override
  List<dynamic> serializeToCssPaint() {
    return <dynamic>[8];
  }

  @override
  void transform(Float64List matrix4, ui.Path targetPath) {
    targetPath.close();
  }

  @override
  String toString() {
    if (assertionsEnabled) {
      return 'Close()';
    } else {
      return super.toString();
    }
  }
}

class _PaintBounds {
  // Bounds of maximum area that is paintable by canvas ops.
  final ui.Rect maxPaintBounds;

  bool _didPaintInsideClipArea = false;
  // Bounds of actually painted area. If _left is not set, reported paintBounds
  // should be empty since growLTRB calls were outside active clipping
  // region.
  double _left, _top, _right, _bottom;
  // Stack of transforms.
  List<Matrix4> _transforms;
  // Stack of clip bounds.
  List<ui.Rect> _clipStack;
  bool _currentMatrixIsIdentity = true;
  Matrix4 _currentMatrix = Matrix4.identity();
  bool _clipRectInitialized = false;
  double _currentClipLeft = 0.0,
      _currentClipTop = 0.0,
      _currentClipRight = 0.0,
      _currentClipBottom = 0.0;

  _PaintBounds(this.maxPaintBounds);

  void translate(double dx, double dy) {
    if (dx != 0.0 || dy != 0.0) {
      _currentMatrixIsIdentity = false;
    }
    _currentMatrix.translate(dx, dy);
  }

  void scale(double sx, double sy) {
    if (sx != 1.0 || sy != 1.0) {
      _currentMatrixIsIdentity = false;
    }
    _currentMatrix.scale(sx, sy);
  }

  void rotateZ(double radians) {
    if (radians != 0.0) {
      _currentMatrixIsIdentity = false;
    }
    _currentMatrix.rotateZ(radians);
  }

  void transform(Float64List matrix4) {
    final Matrix4 m4 = Matrix4.fromFloat64List(matrix4);
    _currentMatrix.multiply(m4);
    _currentMatrixIsIdentity = _currentMatrix.isIdentity();
  }

  void skew(double sx, double sy) {
    _currentMatrixIsIdentity = false;

    // DO NOT USE Matrix4.skew(sx, sy)! It treats sx and sy values as radians,
    // but in our case they are transform matrix values.
    final Matrix4 skewMatrix = Matrix4.identity();
    final Float64List storage = skewMatrix.storage;
    storage[1] = sy;
    storage[4] = sx;
    _currentMatrix.multiply(skewMatrix);
  }

  void clipRect(ui.Rect rect) {
    // If we have an active transform, calculate screen relative clipping
    // rectangle and union with current clipping rectangle.
    if (!_currentMatrixIsIdentity) {
      final Vector3 leftTop =
      _currentMatrix.transform3(Vector3(rect.left, rect.top, 0.0));
      final Vector3 rightTop =
      _currentMatrix.transform3(Vector3(rect.right, rect.top, 0.0));
      final Vector3 leftBottom =
      _currentMatrix.transform3(Vector3(rect.left, rect.bottom, 0.0));
      final Vector3 rightBottom =
      _currentMatrix.transform3(Vector3(rect.right, rect.bottom, 0.0));
      rect = ui.Rect.fromLTRB(
          math.min(math.min(math.min(leftTop.x, rightTop.x), leftBottom.x),
              rightBottom.x),
          math.min(math.min(math.min(leftTop.y, rightTop.y), leftBottom.y),
              rightBottom.y),
          math.max(math.max(math.max(leftTop.x, rightTop.x), leftBottom.x),
              rightBottom.x),
          math.max(math.max(math.max(leftTop.y, rightTop.y), leftBottom.y),
              rightBottom.y));
    }
    if (!_clipRectInitialized) {
      _currentClipLeft = rect.left;
      _currentClipTop = rect.top;
      _currentClipRight = rect.right;
      _currentClipBottom = rect.bottom;
      _clipRectInitialized = true;
    } else {
      if (rect.left > _currentClipLeft) {
        _currentClipLeft = rect.left;
      }
      if (rect.top > _currentClipTop) {
        _currentClipTop = rect.top;
      }
      if (rect.right < _currentClipRight) {
        _currentClipRight = rect.right;
      }
      if (rect.bottom < _currentClipBottom) {
        _currentClipBottom = rect.bottom;
      }
    }
  }

  /// Grow painted area to include given rectangle.
  void grow(ui.Rect r) {
    growLTRB(r.left, r.top, r.right, r.bottom);
  }

  /// Grow painted area to include given rectangle.
  void growLTRB(double left, double top, double right, double bottom) {
    if (left == right || top == bottom) {
      return;
    }

    double transformedPointLeft = left;
    double transformedPointTop = top;
    double transformedPointRight = right;
    double transformedPointBottom = bottom;

    if (!_currentMatrixIsIdentity) {
      final ui.Rect transformedRect =
      transformLTRB(_currentMatrix, left, top, right, bottom);
      transformedPointLeft = transformedRect.left;
      transformedPointTop = transformedRect.top;
      transformedPointRight = transformedRect.right;
      transformedPointBottom = transformedRect.bottom;
    }

    if (_clipRectInitialized) {
      if (transformedPointLeft > _currentClipRight) {
        return;
      }
      if (transformedPointRight < _currentClipLeft) {
        return;
      }
      if (transformedPointTop > _currentClipBottom) {
        return;
      }
      if (transformedPointBottom < _currentClipTop) {
        return;
      }
      if (transformedPointLeft < _currentClipLeft) {
        transformedPointLeft = _currentClipLeft;
      }
      if (transformedPointRight > _currentClipRight) {
        transformedPointRight = _currentClipRight;
      }
      if (transformedPointTop < _currentClipTop) {
        transformedPointTop = _currentClipTop;
      }
      if (transformedPointBottom > _currentClipBottom) {
        transformedPointBottom = _currentClipBottom;
      }
    }

    if (_didPaintInsideClipArea) {
      _left = math.min(
          math.min(_left, transformedPointLeft), transformedPointRight);
      _right = math.max(
          math.max(_right, transformedPointLeft), transformedPointRight);
      _top =
          math.min(math.min(_top, transformedPointTop), transformedPointBottom);
      _bottom = math.max(
          math.max(_bottom, transformedPointTop), transformedPointBottom);
    } else {
      _left = math.min(transformedPointLeft, transformedPointRight);
      _right = math.max(transformedPointLeft, transformedPointRight);
      _top = math.min(transformedPointTop, transformedPointBottom);
      _bottom = math.max(transformedPointTop, transformedPointBottom);
    }
    _didPaintInsideClipArea = true;
  }

  void saveTransformsAndClip() {
    _clipStack ??= <ui.Rect>[];
    _transforms ??= <Matrix4>[];
    _transforms.add(_currentMatrix?.clone());
    _clipStack.add(_clipRectInitialized
        ? ui.Rect.fromLTRB(_currentClipLeft, _currentClipTop, _currentClipRight,
        _currentClipBottom)
        : null);
  }

  void restoreTransformsAndClip() {
    _currentMatrix = _transforms.removeLast();
    final ui.Rect clipRect = _clipStack.removeLast();
    if (clipRect != null) {
      _currentClipLeft = clipRect.left;
      _currentClipTop = clipRect.top;
      _currentClipRight = clipRect.right;
      _currentClipBottom = clipRect.bottom;
      _clipRectInitialized = true;
    } else if (_clipRectInitialized) {
      _clipRectInitialized = false;
    }
  }

  ui.Rect computeBounds() {
    if (!_didPaintInsideClipArea) {
      return ui.Rect.zero;
    }

    // The framework may send us NaNs in the case when it attempts to invert an
    // infinitely size rect.
    final double maxLeft = maxPaintBounds.left.isNaN
        ? double.negativeInfinity
        : maxPaintBounds.left;
    final double maxRight =
    maxPaintBounds.right.isNaN ? double.infinity : maxPaintBounds.right;
    final double maxTop =
    maxPaintBounds.top.isNaN ? double.negativeInfinity : maxPaintBounds.top;
    final double maxBottom =
    maxPaintBounds.bottom.isNaN ? double.infinity : maxPaintBounds.bottom;

    final double left = math.min(_left, _right);
    final double right = math.max(_left, _right);
    final double top = math.min(_top, _bottom);
    final double bottom = math.max(_top, _bottom);

    if (right < maxLeft || bottom < maxTop) {
      // Computed and max bounds do not intersect.
      return ui.Rect.zero;
    }

    return ui.Rect.fromLTRB(
      math.max(left, maxLeft),
      math.max(top, maxTop),
      math.min(right, maxRight),
      math.min(bottom, maxBottom),
    );
  }

  @override
  String toString() {
    if (assertionsEnabled) {
      final ui.Rect bounds = computeBounds();
      return '_PaintBounds($bounds of size ${bounds.size})';
    } else {
      return super.toString();
    }
  }
}


/// Transforms a rectangle given the effective [transform].
///
/// This is the same as [transformRect], except that the rect is specified
/// in terms of left, top, right, and bottom edge offsets.
ui.Rect transformLTRB(
    Matrix4 transform, double left, double top, double right, double bottom) {
  assert(left != null);
  assert(top != null);
  assert(right != null);
  assert(bottom != null);

  // Construct a matrix where each row represents a vector pointing at
  // one of the four corners of the (left, top, right, bottom) rectangle.
  // Using the row-major order allows us to multiply the matrix in-place
  // by the transposed current transformation matrix. The vector_math
  // library has a convenience function `multiplyTranspose` that performs
  // the multiplication without copying. This way we compute the positions
  // of all four points in a single matrix-by-matrix multiplication at the
  // cost of one `Matrix4` instance and one `Float64List` instance.
  //
  // The rejected alternative was to use `Vector3` for each point and
  // multiply by the current transform. However, that would cost us four
  // `Vector3` instances, four `Float64List` instances, and four
  // matrix-by-vector multiplications.
  //
  // `Float64List` initializes the array with zeros, so we do not have to
  // fill in every single element.
  final Float64List pointData = Float64List(16);

  // Row 0: top-left
  pointData[0] = left;
  pointData[4] = top;
  pointData[12] = 1;

  // Row 1: top-right
  pointData[1] = right;
  pointData[5] = top;
  pointData[13] = 1;

  // Row 2: bottom-left
  pointData[2] = left;
  pointData[6] = bottom;
  pointData[14] = 1;

  // Row 3: bottom-right
  pointData[3] = right;
  pointData[7] = bottom;
  pointData[15] = 1;

  final Matrix4 pointMatrix = Matrix4.fromFloat64List(pointData);
  pointMatrix.multiplyTranspose(transform);

  return ui.Rect.fromLTRB(
    math.min(math.min(math.min(pointData[0], pointData[1]), pointData[2]),
        pointData[3]),
    math.min(math.min(math.min(pointData[4], pointData[5]), pointData[6]),
        pointData[7]),
    math.max(math.max(math.max(pointData[0], pointData[1]), pointData[2]),
        pointData[3]),
    math.max(math.max(math.max(pointData[4], pointData[5]), pointData[6]),
        pointData[7]),
  );
}


/// Converts conic curve to a list of quadratic curves for rendering on
/// canvas or conversion to svg.
///
/// See "High order approximation of conic sections by quadratic splines"
/// by Michael Floater, 1993.
/// Skia implementation reference:
/// https://github.com/google/skia/blob/master/src/core/SkGeometry.cpp
class Conic {
  double p0x, p0y, p1x, p1y, p2x, p2y;
  final double fW;
  static const int _maxSubdivisionCount = 5;

  Conic(this.p0x, this.p0y, this.p1x, this.p1y, this.p2x, this.p2y, this.fW);

  /// Returns array of points for the approximation of the conic as quad(s).
  ///
  /// First offset is start Point. Each pair of offsets after are quadratic
  /// control and end points.
  List<ui.Offset> toQuads() {
    final List<ui.Offset> pointList = <ui.Offset>[];
    // This value specifies error bound.
    const double conicTolerance = 1.0 / 4.0;

    // Based on error bound, compute how many times we should subdivide
    final int subdivideCount = _computeSubdivisionCount(conicTolerance);

    // Split conic into quads, writes quad coordinates into [_pointList] and
    // returns number of quads.
    assert(subdivideCount > 0);
    int quadCount = 1 << subdivideCount;
    bool skipSubdivide = false;
    pointList.add(ui.Offset(p0x, p0y));
    if (subdivideCount == _maxSubdivisionCount) {
      // We have an extreme number of quads, chop this conic and check if
      // it generates a pair of lines, in which case we should not subdivide.
      final List<Conic> dst = List<Conic>(2);
      _chop(dst);
      final Conic conic0 = dst[0];
      final Conic conic1 = dst[1];
      // If this chop generates pair of lines no need to subdivide.
      if (conic0.p1x == conic0.p2x &&
          conic0.p1y == conic0.p2y &&
          conic1.p0x == conic1.p1x &&
          conic1.p0y == conic1.p1y) {
        final ui.Offset controlPointOffset = ui.Offset(conic0.p1x, conic0.p1y);
        pointList.add(controlPointOffset);
        pointList.add(controlPointOffset);
        pointList.add(controlPointOffset);
        pointList.add(ui.Offset(conic1.p2x, conic1.p2y));
        quadCount = 2;
        skipSubdivide = true;
      }
    }
    if (!skipSubdivide) {
      _subdivide(this, subdivideCount, pointList);
    }

    // If there are any non-finite generated points, pin to middle of hull.
    final int pointCount = 2 * quadCount + 1;
    bool hasNonFinitePoints = false;
    for (int p = 0; p < pointCount; ++p) {
      if (pointList[p].dx.isNaN || pointList[p].dy.isNaN) {
        hasNonFinitePoints = true;
        break;
      }
    }
    if (hasNonFinitePoints) {
      for (int p = 1; p < pointCount - 1; ++p) {
        pointList[p] = ui.Offset(p1x, p1y);
      }
    }
    return pointList;
  }

  static bool _between(double a, double b, double c) {
    return (a - b) * (c - b) <= 0;
  }

  // Subdivides a conic and writes to points list.
  static void _subdivide(Conic src, int level, List<ui.Offset> pointList) {
    assert(level >= 0);
    if (0 == level) {
      // At lowest subdivision point, copy control point and end point to
      // target.
      pointList.add(ui.Offset(src.p1x, src.p1y));
      pointList.add(ui.Offset(src.p2x, src.p2y));
      return;
    }
    final List<Conic> dst = List<Conic>(2);
    src._chop(dst);
    final Conic conic0 = dst[0];
    final Conic conic1 = dst[1];
    final double startY = src.p0y;
    final double endY = src.p2y;
    final double cpY = src.p1y;
    if (_between(startY, cpY, endY)) {
      // Ensure that chopped conics maintain their y-order.
      final double midY = conic0.p2y;
      if (!_between(startY, midY, endY)) {
        // The computed midpoint is outside end points, move it to
        // closer one.
        final double closerY =
        (midY - startY).abs() < (midY - endY).abs() ? startY : endY;
        conic0.p2y = conic1.p0y = closerY;
      }
      if (!_between(startY, conic0.p1y, conic0.p2y)) {
        // First control point not between start and end points, move it
        // to start.
        conic0.p1y = startY;
      }
      if (!_between(conic1.p0y, conic1.p1y, endY)) {
        // Second control point not between start and end points, move it
        // to end.
        conic1.p1y = endY;
      }
      // Verify that conics points are ordered.
      assert(_between(startY, conic0.p1y, conic0.p2y));
      assert(_between(conic0.p1y, conic0.p2y, conic1.p1y));
      assert(_between(conic0.p2y, conic1.p1y, endY));
    }
    --level;
    _subdivide(conic0, level, pointList);
    _subdivide(conic1, level, pointList);
  }

  static double _subdivideWeightValue(double w) {
    return math.sqrt(0.5 + w * 0.5);
  }

  // Splits conic into 2 parts based on weight.
  void _chop(List<Conic> dst) {
    final double scale = 1.0 / (1.0 + fW);
    final double newW = _subdivideWeightValue(fW);
    final ui.Offset wp1 = ui.Offset(fW * p1x, fW * p1y);
    ui.Offset m = ui.Offset((p0x + (2 * wp1.dx) + p2x) * scale * 0.5,
        (p0y + 2 * wp1.dy + p2y) * scale * 0.5);
    if (m.dx.isNaN || m.dy.isNaN) {
      final double w2 = fW * 2;
      final double scaleHalf = 1.0 / (1 + fW) * 0.5;
      m = ui.Offset((p0x + (w2 * p1x) + p2x) * scaleHalf,
          (p0y + (w2 * p1y) + p2y) * scaleHalf);
    }
    dst[0] = Conic(p0x, p0y, (p0x + wp1.dx) * scale, (p0y + wp1.dy) * scale,
        m.dx, m.dy, newW);
    dst[1] = Conic(m.dx, m.dy, (p2x + wp1.dx) * scale, (p2y + wp1.dy) * scale,
        p2x, p2y, newW);
  }

  /// Computes number of binary subdivisions of the curve given
  /// the tolerance.
  ///
  /// The number of subdivisions never exceed [_maxSubdivisionCount].
  int _computeSubdivisionCount(double tolerance) {
    assert(tolerance.isFinite);
    // Expecting finite coordinates.
    assert(p0x.isFinite &&
        p1x.isFinite &&
        p2x.isFinite &&
        p0y.isFinite &&
        p1y.isFinite &&
        p2y.isFinite);
    if (tolerance < 0) {
      return 0;
    }
    // See "High order approximation of conic sections by quadratic splines"
    // by Michael Floater, 1993.
    // Error bound e0 = |a| |p0 - 2p1 + p2| / 4(2 + a).
    final double a = fW - 1;
    final double k = a / (4.0 * (2.0 + a));
    final double x = k * (p0x - 2 * p1x + p2x);
    final double y = k * (p0y - 2 * p1y + p2y);

    double error = math.sqrt(x * x + y * y);
    int pow2 = 0;
    for (; pow2 < _maxSubdivisionCount; ++pow2) {
      if (error <= tolerance) {
        break;
      }
      error *= 0.25;
    }
    return pow2;
  }
}

