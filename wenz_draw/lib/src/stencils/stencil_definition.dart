import 'package:flutter/widgets.dart';

@immutable
class StencilDefinition {
  const StencilDefinition({
    required this.name,
    required this.width,
    required this.height,
    this.aspect = StencilAspect.variable,
    this.strokeWidth = StencilStrokeWidth.inherited,
    this.background = const <StencilCommand>[],
    this.foreground = const <StencilCommand>[],
    this.connections = const <StencilConnection>[],
  });

  final String name;
  final double width;
  final double height;
  final StencilAspect aspect;
  final StencilStrokeWidth strokeWidth;
  final List<StencilCommand> background;
  final List<StencilCommand> foreground;
  final List<StencilConnection> connections;

  List<StencilCommand> get commands => [...background, ...foreground];
}

enum StencilAspect { variable, fixed }

@immutable
class StencilStrokeWidth {
  const StencilStrokeWidth._(this.value, this.isInherited);

  const StencilStrokeWidth.value(double value) : this._(value, false);
  static const inherited = StencilStrokeWidth._(null, true);

  final double? value;
  final bool isInherited;
}

@immutable
class StencilConnection {
  const StencilConnection({
    required this.x,
    required this.y,
    this.name,
    this.perimeter = true,
  });

  final double x;
  final double y;
  final String? name;
  final bool perimeter;
}

@immutable
sealed class StencilCommand {
  const StencilCommand();
}

@immutable
class StencilPathCommand extends StencilCommand {
  const StencilPathCommand(this.operations);

  final List<StencilPathOperation> operations;
}

@immutable
sealed class StencilPathOperation {
  const StencilPathOperation();
}

@immutable
class StencilMoveTo extends StencilPathOperation {
  const StencilMoveTo(this.x, this.y);

  final double x;
  final double y;
}

@immutable
class StencilLineTo extends StencilPathOperation {
  const StencilLineTo(this.x, this.y);

  final double x;
  final double y;
}

@immutable
class StencilQuadTo extends StencilPathOperation {
  const StencilQuadTo(this.x1, this.y1, this.x2, this.y2);

  final double x1;
  final double y1;
  final double x2;
  final double y2;
}

@immutable
class StencilCurveTo extends StencilPathOperation {
  const StencilCurveTo(this.x1, this.y1, this.x2, this.y2, this.x3, this.y3);

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x3;
  final double y3;
}

@immutable
class StencilArcTo extends StencilPathOperation {
  const StencilArcTo({
    required this.rx,
    required this.ry,
    required this.xAxisRotation,
    required this.largeArcFlag,
    required this.sweepFlag,
    required this.x,
    required this.y,
  });

  final double rx;
  final double ry;
  final double xAxisRotation;
  final bool largeArcFlag;
  final bool sweepFlag;
  final double x;
  final double y;
}

@immutable
class StencilClosePath extends StencilPathOperation {
  const StencilClosePath();
}

@immutable
class StencilRectCommand extends StencilCommand {
  const StencilRectCommand(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;
}

@immutable
class StencilRoundRectCommand extends StencilCommand {
  const StencilRoundRectCommand(
    this.x,
    this.y,
    this.width,
    this.height, {
    this.arcSize,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double? arcSize;
}

@immutable
class StencilEllipseCommand extends StencilCommand {
  const StencilEllipseCommand(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;
}

@immutable
class StencilTextCommand extends StencilCommand {
  const StencilTextCommand({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.value,
    this.align = TextAlign.center,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final String value;
  final TextAlign align;
}

@immutable
class StencilIncludeShapeCommand extends StencilCommand {
  const StencilIncludeShapeCommand({
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
}

@immutable
sealed class StencilStyleCommand extends StencilCommand {
  const StencilStyleCommand();
}

@immutable
class StencilFillStrokeCommand extends StencilStyleCommand {
  const StencilFillStrokeCommand();
}

@immutable
class StencilStrokeCommand extends StencilStyleCommand {
  const StencilStrokeCommand();
}

@immutable
class StencilSaveCommand extends StencilStyleCommand {
  const StencilSaveCommand();
}

@immutable
class StencilRestoreCommand extends StencilStyleCommand {
  const StencilRestoreCommand();
}

@immutable
class StencilStrokeWidthCommand extends StencilStyleCommand {
  const StencilStrokeWidthCommand(this.width);

  final double width;
}

@immutable
class StencilFillColorCommand extends StencilStyleCommand {
  const StencilFillColorCommand({required this.color, this.defaultColor});

  final String color;
  final String? defaultColor;
}

@immutable
class StencilMiterLimitCommand extends StencilStyleCommand {
  const StencilMiterLimitCommand(this.limit);

  final double limit;
}

@immutable
class StencilLineJoinCommand extends StencilStyleCommand {
  const StencilLineJoinCommand(this.join);

  final String join;
}

@immutable
class StencilUnsupportedCommand extends StencilCommand {
  const StencilUnsupportedCommand(this.name);

  final String name;
}
