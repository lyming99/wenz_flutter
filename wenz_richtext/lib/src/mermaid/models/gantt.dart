/// Data models for Gantt Chart diagrams
library;

/// Represents the status of a task
enum GanttTaskStatus {
  /// Task is done
  done,

  /// Task is active/in progress
  active,

  /// Task is critical
  critical,

  /// Task is a milestone
  milestone,

  /// Normal task
  normal,
}

/// Represents a single task in a Gantt chart
class GanttTask {
  /// Creates a Gantt task
  const GanttTask({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.section,
    this.status = GanttTaskStatus.normal,
    this.dependencies = const [],
    this.progress = 0,
  });

  /// Unique identifier for this task
  final String id;

  /// Display name of the task
  final String name;

  /// Start date of the task
  final DateTime startDate;

  /// End date of the task
  final DateTime endDate;

  /// Optional section this task belongs to
  final String? section;

  /// Status of the task
  final GanttTaskStatus status;

  /// List of task IDs this task depends on
  final List<String> dependencies;

  /// Progress percentage (0-100)
  final int progress;

  /// Gets the duration in days
  int get durationDays {
    return endDate.difference(startDate).inDays + 1;
  }

  /// Creates a copy with modified properties
  GanttTask copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? section,
    GanttTaskStatus? status,
    List<String>? dependencies,
    int? progress,
  }) {
    return GanttTask(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      section: section ?? this.section,
      status: status ?? this.status,
      dependencies: dependencies ?? this.dependencies,
      progress: progress ?? this.progress,
    );
  }
}

/// Represents a section in a Gantt chart
class GanttSection {
  /// Creates a Gantt section
  const GanttSection({
    required this.name,
    required this.tasks,
  });

  /// Name of the section
  final String name;

  /// Tasks in this section
  final List<GanttTask> tasks;

  /// Creates a copy with modified properties
  GanttSection copyWith({
    String? name,
    List<GanttTask>? tasks,
  }) {
    return GanttSection(
      name: name ?? this.name,
      tasks: tasks ?? this.tasks,
    );
  }
}

/// Data for a complete Gantt chart
class GanttChartData {
  /// Creates Gantt chart data
  const GanttChartData({
    this.title,
    required this.tasks,
    this.sections = const [],
    this.dateFormat = 'YYYY-MM-DD',
    this.axisFormat,
    this.excludes,
    this.todayMarker = true,
  });

  /// Optional title for the Gantt chart
  final String? title;

  /// All tasks in the Gantt chart
  final List<GanttTask> tasks;

  /// Sections organizing tasks
  final List<GanttSection> sections;

  /// Date format string
  final String dateFormat;

  /// Axis display format
  final String? axisFormat;

  /// Days to exclude (weekends, holidays)
  final String? excludes;

  /// Whether to show today marker
  final bool todayMarker;

  /// Gets the earliest start date among all tasks
  DateTime? get minDate {
    if (tasks.isEmpty) return null;
    return tasks.map((t) => t.startDate).reduce(
          (a, b) => a.isBefore(b) ? a : b,
        );
  }

  /// Gets the latest end date among all tasks
  DateTime? get maxDate {
    if (tasks.isEmpty) return null;
    return tasks.map((t) => t.endDate).reduce(
          (a, b) => a.isAfter(b) ? a : b,
        );
  }

  /// Gets the total duration in days
  int get totalDays {
    final min = minDate;
    final max = maxDate;
    if (min == null || max == null) return 0;
    return max.difference(min).inDays + 1;
  }

  /// Gets a task by its ID
  GanttTask? getTask(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  /// Creates a copy with modified properties
  GanttChartData copyWith({
    String? title,
    List<GanttTask>? tasks,
    List<GanttSection>? sections,
    String? dateFormat,
    String? axisFormat,
    String? excludes,
    bool? todayMarker,
  }) {
    return GanttChartData(
      title: title ?? this.title,
      tasks: tasks ?? this.tasks,
      sections: sections ?? this.sections,
      dateFormat: dateFormat ?? this.dateFormat,
      axisFormat: axisFormat ?? this.axisFormat,
      excludes: excludes ?? this.excludes,
      todayMarker: todayMarker ?? this.todayMarker,
    );
  }
}

/// Default color palette for Gantt charts
class GanttChartColors {
  GanttChartColors._();

  /// Color for done tasks
  static const int doneColor = 0xFF4CAF50; // Green

  /// Color for active tasks
  static const int activeColor = 0xFF2196F3; // Blue

  /// Color for critical tasks
  static const int criticalColor = 0xFFF44336; // Red

  /// Color for milestones
  static const int milestoneColor = 0xFFFF9800; // Orange

  /// Color for normal tasks
  static const int normalColor = 0xFF9E9E9E; // Grey

  /// Today marker color
  static const int todayMarkerColor = 0xFFE91E63; // Pink

  /// Grid line color
  static const int gridLineColor = 0xFFE0E0E0; // Light grey

  /// Section background colors (alternating)
  static const List<int> sectionColors = [
    0xFFF5F5F5, // Grey 100
    0xFFFFFFFF, // White
  ];

  /// Gets color for a task status
  static int getColorForStatus(GanttTaskStatus status) {
    switch (status) {
      case GanttTaskStatus.done:
        return doneColor;
      case GanttTaskStatus.active:
        return activeColor;
      case GanttTaskStatus.critical:
        return criticalColor;
      case GanttTaskStatus.milestone:
        return milestoneColor;
      case GanttTaskStatus.normal:
        return normalColor;
    }
  }
}
