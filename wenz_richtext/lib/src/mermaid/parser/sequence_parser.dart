import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';

/// Parser for Mermaid sequence diagrams
///
/// Supports syntax like:
/// ```
/// sequenceDiagram
///   participant A as Alice
///   participant B as Bob
///   A->>B: Hello
///   B-->>A: Hi
/// ```
class SequenceParser {
  final List<SequenceParticipant> _participants = [];
  final List<SequenceMessage> _messages = [];
  final Map<String, String> _aliases = {};

  /// Parses sequence diagram lines into diagram data
  MermaidDiagramData? parse(List<String> lines) {
    if (lines.isEmpty) return null;

    _participants.clear();
    _messages.clear();
    _aliases.clear();

    // Skip the first line (sequenceDiagram declaration)
    for (var i = 1; i < lines.length; i++) {
      _parseLine(lines[i]);
    }

    // Create nodes from participants
    final nodes = _participants.map((p) => p as MermaidNode).toList();

    // Create edges from messages
    final edges = _messages.map((m) => m as MermaidEdge).toList();

    return MermaidDiagramData(
      type: DiagramType.sequence,
      nodes: nodes,
      edges: edges,
      direction: DiagramDirection.leftToRight,
    );
  }

  void _parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    // Parse participant declarations
    if (trimmed.startsWith('participant ') || trimmed.startsWith('actor ')) {
      _parseParticipant(trimmed);
      return;
    }

    // Parse notes
    if (trimmed.startsWith('Note ') || trimmed.startsWith('note ')) {
      // TODO: Handle notes
      return;
    }

    // Parse activate/deactivate
    if (trimmed.startsWith('activate ') || trimmed.startsWith('deactivate ')) {
      // TODO: Handle activation
      return;
    }

    // Parse loop/alt/opt/par blocks
    if (trimmed.startsWith('loop ') ||
        trimmed.startsWith('alt ') ||
        trimmed.startsWith('opt ') ||
        trimmed.startsWith('par ') ||
        trimmed == 'end' ||
        trimmed.startsWith('else ')) {
      // TODO: Handle control structures
      return;
    }

    // Parse messages
    _parseMessage(trimmed);
  }

  void _parseParticipant(String line) {
    ParticipantType type = ParticipantType.participant;
    String remaining = line;

    if (line.startsWith('actor ')) {
      type = ParticipantType.actor;
      remaining = line.substring(6).trim();
    } else if (line.startsWith('participant ')) {
      remaining = line.substring(12).trim();
    }

    // Check for alias: participant A as Alice
    final asPattern = RegExp(r'^(\w+)\s+as\s+(.+)$');
    final asMatch = asPattern.firstMatch(remaining);

    String id;
    String label;

    if (asMatch != null) {
      id = asMatch.group(1)!;
      label = asMatch.group(2)!;
      _aliases[id] = label;
    } else {
      id = remaining;
      label = remaining;
    }

    _participants.add(SequenceParticipant(
      id: id,
      label: label,
      participantType: type,
    ));
  }

  void _parseMessage(String line) {
    // Message patterns:
    // A->B: message (solid line, no arrow)
    // A-->B: message (dotted line, no arrow)
    // A->>B: message (solid line, arrow)
    // A-->>B: message (dotted line, arrow)
    // A-xB: message (solid line, cross)
    // A--xB: message (dotted line, cross)
    // A-)B: message (solid line, async)
    // A--)B: message (dotted line, async)

    final messagePattern = RegExp(
      r'^(\w+)(--?)(>>?|x|\))?(\w+)(?::\s*(.*))?$',
    );

    final match = messagePattern.firstMatch(line);
    if (match == null) return;

    final from = match.group(1)!;
    final lineStyle = match.group(2)!;
    final arrowStyle = match.group(3) ?? '';
    final to = match.group(4)!;
    final messageText = match.group(5)?.trim();

    // Determine line type
    final lineType = lineStyle == '--' ? LineType.dotted : LineType.solid;

    // Determine arrow type
    ArrowType arrowType;
    MessageType messageType;

    if (arrowStyle.contains('>>')) {
      arrowType = ArrowType.arrow;
      messageType =
          lineType == LineType.dotted ? MessageType.reply : MessageType.sync;
    } else if (arrowStyle.contains('x')) {
      arrowType = ArrowType.cross;
      messageType = MessageType.sync;
    } else if (arrowStyle.contains(')')) {
      arrowType = ArrowType.arrow;
      messageType = lineType == LineType.dotted
          ? MessageType.asyncReply
          : MessageType.async;
    } else if (arrowStyle.contains('>')) {
      arrowType = ArrowType.arrow;
      messageType = MessageType.sync;
    } else {
      arrowType = ArrowType.none;
      messageType = MessageType.sync;
    }

    // Auto-create participants if not declared
    _ensureParticipant(from);
    _ensureParticipant(to);

    _messages.add(SequenceMessage(
      from: from,
      to: to,
      label: messageText,
      arrowType: arrowType,
      lineType: lineType,
      messageType: messageType,
    ));
  }

  void _ensureParticipant(String id) {
    if (!_participants.any((p) => p.id == id)) {
      _participants.add(SequenceParticipant(
        id: id,
        label: _aliases[id] ?? id,
      ));
    }
  }
}
