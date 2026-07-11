/// Parser for Kanban diagrams
library;

import '../models/diagram.dart';
import '../models/kanban.dart';

/// Parser for Mermaid Kanban diagrams
class KanbanParser {
  /// Creates a Kanban parser
  const KanbanParser();

  /// Parses Kanban diagram from cleaned lines
  /// Returns tuple of (MermaidDiagramData, KanbanChartData) or null if invalid
  (MermaidDiagramData, KanbanChartData)? parse(List<String> lines) {
    if (lines.isEmpty) return null;

    String? title;
    String? ticketBaseUrl;
    final columns = <KanbanColumn>[];
    KanbanColumn? currentColumn;
    final currentTasks = <KanbanTask>[];

    var i = 0;

    // Step 1: Check for YAML frontmatter config
    if (lines[i].trim() == '---') {
      final configEnd = _findConfigEnd(lines, i + 1);
      if (configEnd != -1) {
        ticketBaseUrl = _parseConfig(lines.sublist(i + 1, configEnd));
        i = configEnd + 1;
      }
    }

    // Step 2: Parse kanban content
    while (i < lines.length) {
      final line = lines[i];
      final trimmedLine = line.trim();
      i++;

      if (trimmedLine.isEmpty) continue;

      // Skip 'kanban' keyword
      if (trimmedLine.toLowerCase() == 'kanban') continue;

      // Parse title
      if (trimmedLine.toLowerCase().startsWith('title ')) {
        title = trimmedLine.substring(6).trim();
        continue;
      }

      // Check if line is indented (potential task)
      final isIndented = line.startsWith(' ') || line.startsWith('\t');

      // Parse column: columnId[Column Title] or columnId[Column Title] wip:N
      // Columns should NOT be deeply indented (max 2 spaces for formatting)
      final columnMatch =
          RegExp(r'^(\w+)\[([^\]]+)\](?:\s+wip:(\d+))?$').firstMatch(trimmedLine);
      if (columnMatch != null && !line.startsWith('    ')) {
        // Save previous column
        if (currentColumn != null) {
          columns.add(currentColumn.copyWith(tasks: List.from(currentTasks)));
          currentTasks.clear();
        }

        final columnId = columnMatch.group(1)!;
        final columnTitle = columnMatch.group(2)!;
        final wipLimit =
            columnMatch.group(3) != null ? int.tryParse(columnMatch.group(3)!) : null;

        currentColumn = KanbanColumn(
          id: columnId,
          title: columnTitle,
          tasks: const [],
          wipLimit: wipLimit,
        );
        continue;
      }

      // Parse task (must be deeply indented - 4+ spaces or tabs)
      if (isIndented && line.startsWith('    ')) {
        if (currentColumn == null) continue; // Task without column

        final task = _parseTask(trimmedLine);
        if (task != null) {
          currentTasks.add(task);
        }
      }
    }

    // Save last column
    if (currentColumn != null) {
      columns.add(currentColumn.copyWith(tasks: List.from(currentTasks)));
    }

    if (columns.isEmpty) return null;

    final kanbanData = KanbanChartData(
      columns: columns,
      title: title,
      ticketBaseUrl: ticketBaseUrl,
    );

    final diagramData = MermaidDiagramData(
      type: DiagramType.kanban,
      nodes: const [],
      edges: const [],
      title: title,
    );

    return (diagramData, kanbanData);
  }

  /// Parses config block (YAML frontmatter)
  String? _parseConfig(List<String> configLines) {
    for (final line in configLines) {
      // Match: ticketBaseUrl: 'https://example.com/#TICKET#'
      final urlMatch =
          RegExp(r'''ticketBaseUrl:\s*['"]([^'"]+)['"]''').firstMatch(line);
      if (urlMatch != null) {
        return urlMatch.group(1);
      }
    }
    return null;
  }

  /// Finds end of YAML config block
  int _findConfigEnd(List<String> lines, int start) {
    for (var i = start; i < lines.length; i++) {
      if (lines[i].trim() == '---') return i;
    }
    return -1;
  }

  /// Parses single task line
  /// Format: taskId[Task Description] @{ assigned: "Name", ticket: "123", priority: "High" }
  KanbanTask? _parseTask(String line) {
    // Match pattern: taskId[Description] @{ metadata }
    final taskPattern = RegExp(r'^(\w+)\[([^\]]+)\](?:\s+@\{([^}]+)\})?$');

    final match = taskPattern.firstMatch(line);
    if (match == null) return null;

    final id = match.group(1)!;
    final description = match.group(2)!;
    final metadataStr = match.group(3);

    // Parse metadata
    String? assigned;
    String? ticket;
    var priority = KanbanPriority.normal;
    final metadata = <String, String>{};

    if (metadataStr != null) {
      final metaPairs = metadataStr.split(',');
      for (final pair in metaPairs) {
        final parts = pair.split(':');
        if (parts.length != 2) continue;

        final key = parts[0].trim();
        final value = parts[1].trim().replaceAll(RegExp(r'''["']'''), '');

        switch (key) {
          case 'assigned':
            assigned = value;
          case 'ticket':
            ticket = value;
          case 'priority':
            priority = _parsePriority(value);
          default:
            metadata[key] = value;
        }
      }
    }

    return KanbanTask(
      id: id,
      description: description,
      assigned: assigned,
      ticket: ticket,
      priority: priority,
      metadata: metadata,
    );
  }

  /// Parses priority string to enum
  KanbanPriority _parsePriority(String value) {
    switch (value.toLowerCase()) {
      case 'very high':
        return KanbanPriority.veryHigh;
      case 'high':
        return KanbanPriority.high;
      case 'low':
        return KanbanPriority.low;
      case 'very low':
        return KanbanPriority.veryLow;
      default:
        return KanbanPriority.normal;
    }
  }
}
