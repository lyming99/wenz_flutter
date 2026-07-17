import '../models/diagram.dart';
import '../models/gantt.dart';

/// Parser for Mermaid Gantt chart diagrams
///
/// Parses Gantt chart syntax like:
/// ```
/// gantt
///     title A Gantt Diagram
///     dateFormat YYYY-MM-DD
///     section Section 1
///         Task A           :a1, 2024-01-01, 30d
///         Task B           :after a1, 20d
///     section Section 2
///         Task C           :2024-01-15, 12d
/// ```
class GanttParser {
  /// Creates a Gantt chart parser
  const GanttParser();

  /// Parses Gantt chart diagram from cleaned lines
  ///
  /// Returns a tuple of (MermaidDiagramData, GanttChartData) or null if parsing fails
  (MermaidDiagramData, GanttChartData)? parse(List<String> lines) {
    if (lines.isEmpty) return null;

    String? title;
    String dateFormat = 'YYYY-MM-DD';
    String? axisFormat;
    String? excludes;
    bool todayMarker = true;
    String? currentSection;
    final tasks = <GanttTask>[];
    final sections = <GanttSection>[];
    final sectionTasks = <String, List<GanttTask>>{};

    // Default start date if none specified
    var defaultStartDate = DateTime.now();

    // Parse remaining lines
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final lineLower = line.toLowerCase();

      // Parse title
      if (lineLower.startsWith('title ')) {
        title = line.substring(6).trim();
        continue;
      }

      // Parse dateFormat
      if (lineLower.startsWith('dateformat ')) {
        dateFormat = line.substring(11).trim();
        continue;
      }

      // Parse axisFormat
      if (lineLower.startsWith('axisformat ')) {
        axisFormat = line.substring(11).trim();
        continue;
      }

      // Parse excludes
      if (lineLower.startsWith('excludes ')) {
        excludes = line.substring(9).trim();
        continue;
      }

      // Parse todayMarker
      if (lineLower.startsWith('todaymarker ')) {
        todayMarker = line.substring(12).trim().toLowerCase() != 'off';
        continue;
      }

      // Parse section
      if (lineLower.startsWith('section ')) {
        currentSection = line.substring(8).trim();
        if (!sectionTasks.containsKey(currentSection)) {
          sectionTasks[currentSection] = [];
        }
        continue;
      }

      // Parse task
      final task = _parseTask(line, tasks, defaultStartDate, dateFormat, currentSection);
      if (task != null) {
        tasks.add(task);
        if (currentSection != null) {
          sectionTasks[currentSection]!.add(task);
        }
        // Update default start date based on last task's end date
        defaultStartDate = task.endDate.add(const Duration(days: 1));
      }
    }

    if (tasks.isEmpty) return null;

    // Build sections list
    for (final entry in sectionTasks.entries) {
      sections.add(GanttSection(name: entry.key, tasks: entry.value));
    }

    final ganttData = GanttChartData(
      title: title,
      tasks: tasks,
      sections: sections,
      dateFormat: dateFormat,
      axisFormat: axisFormat,
      excludes: excludes,
      todayMarker: todayMarker,
    );

    // Create a minimal diagram data for compatibility
    final diagramData = MermaidDiagramData(
      type: DiagramType.ganttChart,
      nodes: const [],
      edges: const [],
      title: title,
    );

    return (diagramData, ganttData);
  }

  /// Parses a single task line
  ///
  /// Formats supported:
  /// - Task name :id, 2024-01-01, 30d
  /// - Task name :id, 2024-01-01, 2024-01-30
  /// - Task name :after id1, 30d
  /// - Task name :done, id, 2024-01-01, 30d
  /// - Task name :active, id, 2024-01-01, 30d
  /// - Task name :crit, id, 2024-01-01, 30d
  /// - Task name :milestone, id, 2024-01-01, 0d
  GanttTask? _parseTask(
    String line,
    List<GanttTask> existingTasks,
    DateTime defaultStartDate,
    String dateFormat,
    String? section,
  ) {
    // Split by colon to get name and definition
    final colonIndex = line.indexOf(':');
    if (colonIndex == -1) return null;

    final name = line.substring(0, colonIndex).trim();
    final definition = line.substring(colonIndex + 1).trim();

    if (name.isEmpty || definition.isEmpty) return null;

    // Parse the definition parts
    final parts = definition.split(',').map((s) => s.trim()).toList();
    if (parts.isEmpty) return null;

    // Determine status and extract relevant parts
    var status = GanttTaskStatus.normal;
    String? id;
    String? startSpec;
    String? durationSpec;
    var partIndex = 0;

    // Check for status keywords
    final firstPart = parts[partIndex].toLowerCase();
    if (firstPart == 'done') {
      status = GanttTaskStatus.done;
      partIndex++;
    } else if (firstPart == 'active') {
      status = GanttTaskStatus.active;
      partIndex++;
    } else if (firstPart == 'crit' || firstPart == 'critical') {
      status = GanttTaskStatus.critical;
      partIndex++;
    } else if (firstPart == 'milestone') {
      status = GanttTaskStatus.milestone;
      partIndex++;
    }

    // Parse remaining parts based on count
    final remainingParts = parts.sublist(partIndex);

    if (remainingParts.isEmpty) return null;

    final dependencies = <String>[];

    if (remainingParts.length == 1) {
      // Just duration: 30d
      durationSpec = remainingParts[0];
      id = _generateId(name);
    } else if (remainingParts.length == 2) {
      // Could be: id, duration OR start, duration OR after id, duration
      final first = remainingParts[0];
      final second = remainingParts[1];

      if (first.toLowerCase().startsWith('after ')) {
        // after id, duration
        final afterId = first.substring(6).trim();
        dependencies.add(afterId);
        durationSpec = second;
        id = _generateId(name);

        // Find the referenced task's end date
        final refTask = existingTasks.firstWhere(
          (t) => t.id == afterId,
          orElse: () => GanttTask(
            id: '',
            name: '',
            startDate: defaultStartDate,
            endDate: defaultStartDate,
          ),
        );
        if (refTask.id.isNotEmpty) {
          defaultStartDate = refTask.endDate.add(const Duration(days: 1));
        }
        startSpec = null;
      } else if (_isDate(first, dateFormat)) {
        // start, duration
        startSpec = first;
        durationSpec = second;
        id = _generateId(name);
      } else {
        // id, duration
        id = first;
        durationSpec = second;
      }
    } else if (remainingParts.length >= 3) {
      // id, start, duration OR status was already parsed and we have id, start, duration
      id = remainingParts[0];

      final second = remainingParts[1];
      if (second.toLowerCase().startsWith('after ')) {
        final afterId = second.substring(6).trim();
        dependencies.add(afterId);
        durationSpec = remainingParts[2];

        final refTask = existingTasks.firstWhere(
          (t) => t.id == afterId,
          orElse: () => GanttTask(
            id: '',
            name: '',
            startDate: defaultStartDate,
            endDate: defaultStartDate,
          ),
        );
        if (refTask.id.isNotEmpty) {
          defaultStartDate = refTask.endDate.add(const Duration(days: 1));
        }
      } else {
        startSpec = second;
        durationSpec = remainingParts[2];
      }
    }

    // Parse start date
    DateTime startDate;
    if (startSpec != null) {
      startDate = _parseDate(startSpec, dateFormat) ?? defaultStartDate;
    } else {
      startDate = defaultStartDate;
    }

    // Parse end date/duration
    DateTime endDate;
    if (durationSpec != null) {
      if (_isDate(durationSpec, dateFormat)) {
        // It's an end date
        endDate = _parseDate(durationSpec, dateFormat) ?? startDate;
      } else {
        // It's a duration
        final duration = _parseDuration(durationSpec);
        endDate = startDate.add(Duration(days: duration - 1));
      }
    } else {
      // Default 1 day duration
      endDate = startDate;
    }

    // Ensure milestone has same start and end date
    if (status == GanttTaskStatus.milestone) {
      endDate = startDate;
    }

    return GanttTask(
      id: id ?? _generateId(name),
      name: name,
      startDate: startDate,
      endDate: endDate,
      section: section,
      status: status,
      dependencies: dependencies,
    );
  }

  /// Generates an ID from the task name
  String _generateId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  /// Checks if a string looks like a date
  bool _isDate(String str, String format) {
    // Check for common date patterns
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(str)) return true;
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(str)) return true;
    if (RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(str)) return true;
    return false;
  }

  /// Parses a date string according to the format
  DateTime? _parseDate(String dateStr, String format) {
    try {
      // Handle YYYY-MM-DD format
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
        return DateTime.parse(dateStr);
      }

      // Handle DD/MM/YYYY format
      final ddmmyyyy = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(dateStr);
      if (ddmmyyyy != null) {
        final day = int.parse(ddmmyyyy.group(1)!);
        final month = int.parse(ddmmyyyy.group(2)!);
        final year = int.parse(ddmmyyyy.group(3)!);
        return DateTime(year, month, day);
      }

      // Handle MM-DD-YYYY format
      final mmddyyyy = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(dateStr);
      if (mmddyyyy != null) {
        final month = int.parse(mmddyyyy.group(1)!);
        final day = int.parse(mmddyyyy.group(2)!);
        final year = int.parse(mmddyyyy.group(3)!);
        return DateTime(year, month, day);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Parses a duration string (e.g., "30d", "2w", "1M")
  int _parseDuration(String duration) {
    final durationPattern = RegExp(r'^(\d+)([dwmMy]?)$');
    final match = durationPattern.firstMatch(duration.trim());

    if (match == null) return 1;

    final value = int.parse(match.group(1)!);
    final unit = match.group(2) ?? 'd';

    switch (unit.toLowerCase()) {
      case 'd':
        return value;
      case 'w':
        return value * 7;
      case 'm':
        return value * 30; // Approximate
      case 'y':
        return value * 365; // Approximate
      default:
        return value;
    }
  }
}
