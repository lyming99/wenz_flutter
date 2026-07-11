import '../models/diagram.dart';
import '../models/timeline.dart';

/// Parser for Mermaid Timeline diagrams
///
/// Parses Timeline syntax like:
/// ```
/// timeline
///     title History of Social Media Platform
///     2002 : LinkedIn
///     2004 : Facebook
///          : Google
///     2005 : Youtube
///     2006 : Twitter
/// ```
class TimelineParser {
  /// Creates a Timeline parser
  const TimelineParser();

  /// Parses Timeline diagram from cleaned lines
  ///
  /// Returns a tuple of (MermaidDiagramData, TimelineChartData) or null if parsing fails
  (MermaidDiagramData, TimelineChartData)? parse(List<String> lines) {
    if (lines.isEmpty) return null;

    String? title;
    final sections = <TimelineSection>[];
    String? currentPeriod;
    final currentEvents = <TimelineEvent>[];

    // Parse all lines (timeline keyword already stripped by caller)
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final lineLower = line.toLowerCase();

      // Parse title
      if (lineLower.startsWith('title ')) {
        title = line.substring(6).trim();
        continue;
      }

      // Parse section or event
      if (line.contains(':')) {
        final colonIndex = line.indexOf(':');
        final leftPart = line.substring(0, colonIndex).trim();
        final rightPart = line.substring(colonIndex + 1).trim();

        if (leftPart.isEmpty && rightPart.isNotEmpty) {
          // Continuation of previous period: "     : Event"
          if (currentPeriod != null && rightPart.isNotEmpty) {
            currentEvents.add(TimelineEvent(
              title: rightPart,
              periods: [currentPeriod],
            ));
          }
        } else if (leftPart.isNotEmpty && rightPart.isNotEmpty) {
          // New period with event: "2004 : Facebook"
          // Save previous section if exists
          if (currentPeriod != null && currentEvents.isNotEmpty) {
            sections.add(TimelineSection(
              title: currentPeriod,
              events: List.from(currentEvents),
            ));
            currentEvents.clear();
          }

          currentPeriod = leftPart;
          currentEvents.add(TimelineEvent(
            title: rightPart,
            periods: [currentPeriod],
          ));
        } else if (leftPart.isNotEmpty && rightPart.isEmpty) {
          // Just a period marker: "2004 :"
          // Save previous section if exists
          if (currentPeriod != null && currentEvents.isNotEmpty) {
            sections.add(TimelineSection(
              title: currentPeriod,
              events: List.from(currentEvents),
            ));
            currentEvents.clear();
          }
          currentPeriod = leftPart;
        }
      } else {
        // Line without colon - could be a section title or event continuation
        // For now, treat it as part of the previous event if it exists
        if (currentEvents.isNotEmpty) {
          final lastEvent = currentEvents.last;
          currentEvents[currentEvents.length - 1] = lastEvent.copyWith(
            description: line,
          );
        }
      }
    }

    // Add the last section
    if (currentPeriod != null && currentEvents.isNotEmpty) {
      sections.add(TimelineSection(
        title: currentPeriod,
        events: List.from(currentEvents),
      ));
    }

    if (sections.isEmpty) return null;

    final timelineData = TimelineChartData(
      title: title,
      sections: sections,
    );

    // Create a minimal diagram data for compatibility
    final diagramData = MermaidDiagramData(
      type: DiagramType.timeline,
      nodes: const [],
      edges: const [],
      title: title,
    );

    return (diagramData, timelineData);
  }
}
