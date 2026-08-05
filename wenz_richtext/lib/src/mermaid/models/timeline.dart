/// Data models for Timeline diagrams
library;

/// Represents a single event in a timeline
class TimelineEvent {
  /// Creates a timeline event
  const TimelineEvent({
    required this.title,
    required this.periods,
    this.description,
  });

  /// Title/name of the event
  final String title;

  /// List of time periods or dates associated with this event
  final List<String> periods;

  /// Optional description
  final String? description;

  /// Creates a copy with modified properties
  TimelineEvent copyWith({
    String? title,
    List<String>? periods,
    String? description,
  }) {
    return TimelineEvent(
      title: title ?? this.title,
      periods: periods ?? this.periods,
      description: description ?? this.description,
    );
  }
}

/// Represents a section in a timeline
class TimelineSection {
  /// Creates a timeline section
  const TimelineSection({
    required this.title,
    required this.events,
  });

  /// Title of the section
  final String title;

  /// Events in this section
  final List<TimelineEvent> events;

  /// Creates a copy with modified properties
  TimelineSection copyWith({
    String? title,
    List<TimelineEvent>? events,
  }) {
    return TimelineSection(
      title: title ?? this.title,
      events: events ?? this.events,
    );
  }
}

/// Data for a complete timeline chart
class TimelineChartData {
  /// Creates timeline chart data
  const TimelineChartData({
    this.title,
    required this.sections,
  });

  /// Optional title for the timeline
  final String? title;

  /// Sections organizing events
  final List<TimelineSection> sections;

  /// Gets all events across all sections
  List<TimelineEvent> get allEvents {
    return sections.expand((section) => section.events).toList();
  }

  /// Creates a copy with modified properties
  TimelineChartData copyWith({
    String? title,
    List<TimelineSection>? sections,
  }) {
    return TimelineChartData(
      title: title ?? this.title,
      sections: sections ?? this.sections,
    );
  }
}

/// Default color palette for timeline charts
class TimelineChartColors {
  TimelineChartColors._();

  /// Primary timeline color
  static const int primaryColor = 0xFF2196F3; // Blue

  /// Secondary timeline color
  static const int secondaryColor = 0xFF4CAF50; // Green

  /// Accent color for events
  static const int accentColor = 0xFFFF9800; // Orange

  /// Text color
  static const int textColor = 0xFF212121; // Dark grey

  /// Grid line color
  static const int gridLineColor = 0xFFE0E0E0; // Light grey

  /// Section colors (alternating)
  static const List<int> sectionColors = [
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFF9C27B0, // Purple
    0xFFF44336, // Red
    0xFF00BCD4, // Cyan
    0xFFFFEB3B, // Yellow
    0xFF795548, // Brown
  ];

  /// Gets color for a section by index
  static int getColorForSection(int index) {
    return sectionColors[index % sectionColors.length];
  }
}
