import 'package:flutter/widgets.dart';

/// Device type for responsive layout
enum DeviceType {
  /// Mobile phone (width < 600)
  mobile,

  /// Tablet (600 <= width < 1024)
  tablet,

  /// Desktop/PC (width >= 1024)
  desktop,
}

/// Responsive configuration for Mermaid diagrams
class MermaidResponsiveConfig {
  /// Creates responsive config
  const MermaidResponsiveConfig({
    this.mobileBreakpoint = 600,
    this.tabletBreakpoint = 1024,
    this.mobileConfig = const MermaidDeviceConfig.mobile(),
    this.tabletConfig = const MermaidDeviceConfig.tablet(),
    this.desktopConfig = const MermaidDeviceConfig.desktop(),
  });

  /// Breakpoint for mobile devices
  final double mobileBreakpoint;

  /// Breakpoint for tablet devices
  final double tabletBreakpoint;

  /// Configuration for mobile devices
  final MermaidDeviceConfig mobileConfig;

  /// Configuration for tablet devices
  final MermaidDeviceConfig tabletConfig;

  /// Configuration for desktop devices
  final MermaidDeviceConfig desktopConfig;

  /// Gets the device type based on width
  DeviceType getDeviceType(double width) {
    if (width < mobileBreakpoint) {
      return DeviceType.mobile;
    } else if (width < tabletBreakpoint) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  /// Gets the configuration for a given width
  MermaidDeviceConfig getConfigForWidth(double width) {
    final deviceType = getDeviceType(width);
    return getConfigForDevice(deviceType);
  }

  /// Gets the configuration for a device type
  MermaidDeviceConfig getConfigForDevice(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.mobile:
        return mobileConfig;
      case DeviceType.tablet:
        return tabletConfig;
      case DeviceType.desktop:
        return desktopConfig;
    }
  }

  /// Creates config from BuildContext
  static MermaidDeviceConfig fromContext(
    BuildContext context, [
    MermaidResponsiveConfig? config,
  ]) {
    final width = MediaQuery.of(context).size.width;
    final responsiveConfig = config ?? const MermaidResponsiveConfig();
    return responsiveConfig.getConfigForWidth(width);
  }
}

/// Device-specific configuration
class MermaidDeviceConfig {
  /// Creates device config
  const MermaidDeviceConfig({
    required this.deviceType,
    required this.padding,
    required this.nodeSpacingX,
    required this.nodeSpacingY,
    required this.fontSize,
    required this.titleFontSize,
    required this.minNodeWidth,
    required this.minNodeHeight,
    required this.participantSpacing,
    required this.messageSpacing,
    required this.pieMinRadius,
    required this.legendFontSize,
    required this.scaleFactor,
    required this.showLegendBelow,
  });

  /// Mobile configuration
  const MermaidDeviceConfig.mobile()
      : deviceType = DeviceType.mobile,
        padding = 12.0,
        nodeSpacingX = 30.0,
        nodeSpacingY = 25.0,
        fontSize = 11.0,
        titleFontSize = 14.0,
        minNodeWidth = 60.0,
        minNodeHeight = 30.0,
        participantSpacing = 80.0,
        messageSpacing = 40.0,
        pieMinRadius = 50.0,
        legendFontSize = 10.0,
        scaleFactor = 0.8,
        showLegendBelow = true;

  /// Tablet configuration
  const MermaidDeviceConfig.tablet()
      : deviceType = DeviceType.tablet,
        padding = 16.0,
        nodeSpacingX = 50.0,
        nodeSpacingY = 40.0,
        fontSize = 13.0,
        titleFontSize = 15.0,
        minNodeWidth = 80.0,
        minNodeHeight = 36.0,
        participantSpacing = 120.0,
        messageSpacing = 45.0,
        pieMinRadius = 70.0,
        legendFontSize = 11.0,
        scaleFactor = 0.9,
        showLegendBelow = false;

  /// Desktop configuration
  const MermaidDeviceConfig.desktop()
      : deviceType = DeviceType.desktop,
        padding = 20.0,
        nodeSpacingX = 80.0,
        nodeSpacingY = 50.0,
        fontSize = 14.0,
        titleFontSize = 16.0,
        minNodeWidth = 100.0,
        minNodeHeight = 40.0,
        participantSpacing = 150.0,
        messageSpacing = 50.0,
        pieMinRadius = 90.0,
        legendFontSize = 11.0,
        scaleFactor = 1.0,
        showLegendBelow = false;

  /// Device type
  final DeviceType deviceType;

  /// Padding around the diagram
  final double padding;

  /// Horizontal spacing between nodes
  final double nodeSpacingX;

  /// Vertical spacing between nodes
  final double nodeSpacingY;

  /// Base font size for labels
  final double fontSize;

  /// Font size for titles
  final double titleFontSize;

  /// Minimum node width
  final double minNodeWidth;

  /// Minimum node height
  final double minNodeHeight;

  /// Spacing between participants in sequence diagrams
  final double participantSpacing;

  /// Spacing between messages in sequence diagrams
  final double messageSpacing;

  /// Minimum pie chart radius
  final double pieMinRadius;

  /// Font size for legend text
  final double legendFontSize;

  /// Overall scale factor
  final double scaleFactor;

  /// Whether to show legend below the chart (for mobile)
  final bool showLegendBelow;

  /// Creates a copy with modified properties
  MermaidDeviceConfig copyWith({
    DeviceType? deviceType,
    double? padding,
    double? nodeSpacingX,
    double? nodeSpacingY,
    double? fontSize,
    double? titleFontSize,
    double? minNodeWidth,
    double? minNodeHeight,
    double? participantSpacing,
    double? messageSpacing,
    double? pieMinRadius,
    double? legendFontSize,
    double? scaleFactor,
    bool? showLegendBelow,
  }) {
    return MermaidDeviceConfig(
      deviceType: deviceType ?? this.deviceType,
      padding: padding ?? this.padding,
      nodeSpacingX: nodeSpacingX ?? this.nodeSpacingX,
      nodeSpacingY: nodeSpacingY ?? this.nodeSpacingY,
      fontSize: fontSize ?? this.fontSize,
      titleFontSize: titleFontSize ?? this.titleFontSize,
      minNodeWidth: minNodeWidth ?? this.minNodeWidth,
      minNodeHeight: minNodeHeight ?? this.minNodeHeight,
      participantSpacing: participantSpacing ?? this.participantSpacing,
      messageSpacing: messageSpacing ?? this.messageSpacing,
      pieMinRadius: pieMinRadius ?? this.pieMinRadius,
      legendFontSize: legendFontSize ?? this.legendFontSize,
      scaleFactor: scaleFactor ?? this.scaleFactor,
      showLegendBelow: showLegendBelow ?? this.showLegendBelow,
    );
  }
}
