import '../core/model/rich_text_document.dart';
import '../core/position/document_position.dart';
import 'external_image_input.dart';

/// Identifies which editor interaction requested an external-image insertion.
enum ExternalImageInsertionSource { clipboard, drop }

/// Immutable input passed to a host insertion-position resolver.
class ExternalImageInsertionContext {
  const ExternalImageInsertionContext({
    required this.source,
    required this.document,
    required this.images,
    required this.currentSelection,
    required this.suggestedSelection,
  });

  final ExternalImageInsertionSource source;
  final RichTextDocument document;
  final List<ExternalImageBlockDescription> images;

  /// Selection currently owned by the editor.
  final DocumentSelection? currentSelection;

  /// Interaction-specific target. For drops this is the pointer hit-test
  /// position; for clipboard paste this is the current editor selection.
  final DocumentSelection? suggestedSelection;
}

/// Lets a host choose where prepared image files are inserted.
///
/// Returning `null` keeps the editor's suggested target. The resolved
/// selection still uses the controller's normal command and history path.
typedef ExternalImageInsertionSelectionResolver =
    DocumentSelection? Function(ExternalImageInsertionContext context);
