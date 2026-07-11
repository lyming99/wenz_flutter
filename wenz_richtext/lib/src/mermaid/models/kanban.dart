/// Data models for Kanban diagrams
library;

/// Priority levels for Kanban tasks
enum KanbanPriority {
  /// Very high priority
  veryHigh,

  /// High priority
  high,

  /// Normal priority (default)
  normal,

  /// Low priority
  low,

  /// Very low priority
  veryLow,
}

/// Represents a single task card in Kanban board
class KanbanTask {
  /// Creates a Kanban task
  const KanbanTask({
    required this.id,
    required this.description,
    this.assigned,
    this.ticket,
    this.priority = KanbanPriority.normal,
    this.metadata = const {},
  });

  /// Task identifier
  final String id;

  /// Task description text
  final String description;

  /// Assignee name
  final String? assigned;

  /// Ticket ID/number
  final String? ticket;

  /// Task priority level
  final KanbanPriority priority;

  /// Additional metadata key-value pairs
  final Map<String, String> metadata;

  /// Creates a copy with modified properties
  KanbanTask copyWith({
    String? id,
    String? description,
    String? assigned,
    String? ticket,
    KanbanPriority? priority,
    Map<String, String>? metadata,
  }) {
    return KanbanTask(
      id: id ?? this.id,
      description: description ?? this.description,
      assigned: assigned ?? this.assigned,
      ticket: ticket ?? this.ticket,
      priority: priority ?? this.priority,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is KanbanTask &&
        other.id == id &&
        other.description == description &&
        other.assigned == assigned &&
        other.ticket == ticket &&
        other.priority == priority;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      description,
      assigned,
      ticket,
      priority,
    );
  }
}

/// Represents a column in Kanban board
class KanbanColumn {
  /// Creates a Kanban column
  const KanbanColumn({
    required this.id,
    required this.title,
    required this.tasks,
    this.wipLimit,
  });

  /// Column identifier
  final String id;

  /// Column display title
  final String title;

  /// Tasks in this column
  final List<KanbanTask> tasks;

  /// Work-in-progress limit
  final int? wipLimit;

  /// Returns true if column is over WIP limit
  bool get isOverLimit => wipLimit != null && tasks.length > wipLimit!;

  /// Creates a copy with modified properties
  KanbanColumn copyWith({
    String? id,
    String? title,
    List<KanbanTask>? tasks,
    int? wipLimit,
  }) {
    return KanbanColumn(
      id: id ?? this.id,
      title: title ?? this.title,
      tasks: tasks ?? this.tasks,
      wipLimit: wipLimit ?? this.wipLimit,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is KanbanColumn &&
        other.id == id &&
        other.title == title &&
        other.wipLimit == wipLimit;
  }

  @override
  int get hashCode {
    return Object.hash(id, title, wipLimit);
  }
}

/// Data for a complete Kanban chart
class KanbanChartData {
  /// Creates Kanban chart data
  const KanbanChartData({
    required this.columns,
    this.title,
    this.ticketBaseUrl,
  });

  /// Optional title for the Kanban board
  final String? title;

  /// Columns organizing tasks
  final List<KanbanColumn> columns;

  /// Base URL for ticket links (e.g., 'https://jira.com/browse/#TICKET#')
  final String? ticketBaseUrl;

  /// Gets all tasks across all columns
  List<KanbanTask> get allTasks {
    return columns.expand((column) => column.tasks).toList();
  }

  /// Gets task by ID
  KanbanTask? getTask(String id) {
    for (final column in columns) {
      for (final task in column.tasks) {
        if (task.id == id) return task;
      }
    }
    return null;
  }

  /// Creates a copy with modified properties
  KanbanChartData copyWith({
    String? title,
    List<KanbanColumn>? columns,
    String? ticketBaseUrl,
  }) {
    return KanbanChartData(
      title: title ?? this.title,
      columns: columns ?? this.columns,
      ticketBaseUrl: ticketBaseUrl ?? this.ticketBaseUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is KanbanChartData &&
        other.title == title &&
        other.ticketBaseUrl == ticketBaseUrl;
  }

  @override
  int get hashCode {
    return Object.hash(title, ticketBaseUrl);
  }
}

/// Default color palette for Kanban charts
class KanbanChartColors {
  KanbanChartColors._();

  /// Card background color
  static const int cardBackground = 0xFFFFFFFF; // White

  /// Card border color
  static const int cardBorder = 0xFFE0E0E0; // Light grey

  /// Very high priority color
  static const int veryHighPriority = 0xFFD32F2F; // Red

  /// High priority color
  static const int highPriority = 0xFFFF9800; // Orange

  /// Normal priority color
  static const int normalPriority = 0xFF9E9E9E; // Grey

  /// Low priority color
  static const int lowPriority = 0xFF2196F3; // Blue

  /// Very low priority color
  static const int veryLowPriority = 0xFF4CAF50; // Green

  /// Column header background color
  static const int columnHeader = 0xFFF5F5F5; // Light grey

  /// Column border color
  static const int columnBorder = 0xFFBDBDBD; // Grey

  /// WIP warning color (at limit)
  static const int wipWarning = 0xFFFFC107; // Amber

  /// WIP over limit color
  static const int wipOverLimit = 0xFFF44336; // Red

  /// Text color
  static const int textColor = 0xFF212121; // Dark grey

  /// Assignee avatar background colors (cycling)
  static const List<int> avatarColors = [
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFF9C27B0, // Purple
    0xFFE91E63, // Pink
    0xFF00BCD4, // Cyan
    0xFFFFEB3B, // Yellow
    0xFF795548, // Brown
  ];

  /// Gets color for priority level
  static int getColorForPriority(KanbanPriority priority) {
    switch (priority) {
      case KanbanPriority.veryHigh:
        return veryHighPriority;
      case KanbanPriority.high:
        return highPriority;
      case KanbanPriority.normal:
        return normalPriority;
      case KanbanPriority.low:
        return lowPriority;
      case KanbanPriority.veryLow:
        return veryLowPriority;
    }
  }

  /// Gets avatar color by hash of assignee name
  static int getAvatarColor(String assignee) {
    final hash = assignee.hashCode.abs();
    return avatarColors[hash % avatarColors.length];
  }
}
