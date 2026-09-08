import 'package:flutter/foundation.dart';

/// The rendering category of a chat message.
enum WenzChatMessageKind {
  /// A regular text message rendered as a bubble by the default renderer.
  text,

  /// A centered system message, such as a room notice.
  system,

  /// Application-defined content rendered by [WenzChatView.messageBuilder].
  custom,
}

/// Delivery state displayed for outgoing messages by the default renderer.
enum WenzChatMessageStatus { sending, sent, delivered, read, failed }

/// Immutable data consumed by [WenzChatView].
///
/// [metadata] and [payload] are intentionally application-defined so image,
/// file, audio, card, and rich-text renderers can be added without coupling the
/// package to networking or media dependencies.
@immutable
class WenzChatMessage {
  const WenzChatMessage({
    required this.id,
    required this.authorId,
    required this.sentAt,
    this.text = '',
    this.kind = WenzChatMessageKind.text,
    this.status = WenzChatMessageStatus.sent,
    this.authorName,
    this.payload,
    this.metadata = const <String, Object?>{},
  }) : assert(id != '', 'A message id cannot be empty.'),
       assert(authorId != '', 'An author id cannot be empty.');

  /// Stable identity used for keyed, incremental list rendering.
  final String id;

  /// Identity of the sender. It is compared with `currentUserId` by the view.
  final String authorId;

  /// The time at which the message was sent.
  final DateTime sentAt;

  /// Plain text used by the default bubble and accessibility semantics.
  final String text;

  final WenzChatMessageKind kind;
  final WenzChatMessageStatus status;

  /// Optional display name used by the default incoming bubble.
  final String? authorName;

  /// Optional application-owned data for a custom renderer.
  final Object? payload;

  /// Lightweight extension data. Treat the supplied map as immutable.
  final Map<String, Object?> metadata;

  /// Returns a new message while retaining all unspecified fields.
  WenzChatMessage copyWith({
    String? id,
    String? authorId,
    DateTime? sentAt,
    String? text,
    WenzChatMessageKind? kind,
    WenzChatMessageStatus? status,
    Object? authorName = _notProvided,
    Object? payload = _notProvided,
    Map<String, Object?>? metadata,
  }) {
    return WenzChatMessage(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      sentAt: sentAt ?? this.sentAt,
      text: text ?? this.text,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      authorName: identical(authorName, _notProvided)
          ? this.authorName
          : authorName as String?,
      payload: identical(payload, _notProvided) ? this.payload : payload,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Whether replacing this message can alter neighbouring groups or dates.
  bool hasSameLayoutIdentity(WenzChatMessage other) {
    return authorId == other.authorId &&
        sentAt == other.sentAt &&
        kind == other.kind;
  }

  static const Object _notProvided = Object();
}
