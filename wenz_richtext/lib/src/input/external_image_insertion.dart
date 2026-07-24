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
/// selection is passed through the controller's normal command/history path,
/// so replacement, undo/redo, permissions, and post-insert selection remain
/// consistent with an ordinary image paste.
typedef ExternalImageInsertionSelectionResolver = DocumentSelection? Function(
    ExternalImageInsertionContext context);

/// Prepares clipboard/drop image candidates for one ordered insertion.
///
/// A file candidate followed by its rendered memory flavor is treated as one
/// logical image. The original file is stored first; the memory flavor is only
/// stored when the file cannot be used, or when it is needed to recover missing
/// pixel metadata. Unrelated candidates retain their clipboard order.
Future<List<ExternalImageBlockDescription>> prepareExternalImagesForInsertion(
  List<ExternalImageInput> inputs, {
  required ExternalImageStore store,
}) async {
  if (inputs.isEmpty) {
    return const <ExternalImageBlockDescription>[];
  }
  final descriptions = <ExternalImageBlockDescription>[];
  final consumedIndexes = <int>{};
  for (var index = 0; index < inputs.length; index++) {
    if (consumedIndexes.contains(index)) {
      continue;
    }
    final input = inputs[index];
    final relatedIndex = _relatedInputIndex(inputs, index, consumedIndexes);
    final relatedInput = relatedIndex == null ? null : inputs[relatedIndex];
    final fileInput = relatedInput == null
        ? null
        : _isFileInput(input)
            ? input
            : relatedInput;
    final memoryFallback = relatedInput == null
        ? null
        : input.kind == ExternalImageInputKind.memory
            ? input
            : relatedInput;
    final ExternalImageBlockDescription? description;
    if (fileInput != null && memoryFallback != null) {
      description = await _prepareWithMemoryFallback(
        store: store,
        fileInput: fileInput,
        memoryFallback: memoryFallback,
      );
    } else {
      description = await _prepare(store, input);
    }
    if (description != null) {
      descriptions.add(description);
    }
    consumedIndexes.add(index);
    if (relatedIndex != null) {
      consumedIndexes.add(relatedIndex);
    }
  }
  return descriptions;
}

Future<ExternalImageBlockDescription?> _prepare(
  ExternalImageStore store,
  ExternalImageInput input,
) async {
  try {
    return (await store.prepare(input)).description;
  } on Object {
    return null;
  }
}

Future<ExternalImageBlockDescription?> _prepareWithMemoryFallback({
  required ExternalImageStore store,
  required ExternalImageInput fileInput,
  required ExternalImageInput memoryFallback,
}) async {
  final fallbackPixelSize =
      externalImagePixelSizeFromBytes(memoryFallback.bytes);
  final fileDescription = await _prepare(store, fileInput);
  if (fileDescription == null) {
    return _prepare(store, memoryFallback);
  }
  if (_shouldUseFallbackPixelSize(fileDescription, fallbackPixelSize)) {
    return _withPixelSize(fileDescription, fallbackPixelSize!);
  }
  if (_hasPixelSize(fileDescription)) {
    return fileDescription;
  }
  final fallbackDescription = await _prepare(store, memoryFallback);
  if (fallbackDescription != null && _hasPixelSize(fallbackDescription)) {
    return _withDimensions(fileDescription, fallbackDescription);
  }
  return fileDescription;
}

int? _relatedInputIndex(
  List<ExternalImageInput> inputs,
  int index,
  Set<int> consumedIndexes,
) {
  final input = inputs[index];
  if (!input.isAccepted ||
      (!_isFileInput(input) && input.kind != ExternalImageInputKind.memory)) {
    return null;
  }
  final preferredIndex = index + 1;
  if (preferredIndex < inputs.length &&
      !consumedIndexes.contains(preferredIndex) &&
      _mayDescribeSameImage(input, inputs[preferredIndex], adjacent: true)) {
    return preferredIndex;
  }
  for (var candidateIndex = 0;
      candidateIndex < inputs.length;
      candidateIndex++) {
    if (candidateIndex == index || consumedIndexes.contains(candidateIndex)) {
      continue;
    }
    if (_mayDescribeSameImage(
      input,
      inputs[candidateIndex],
      adjacent: (candidateIndex - index).abs() == 1,
    )) {
      return candidateIndex;
    }
  }
  return null;
}

bool _mayDescribeSameImage(
  ExternalImageInput first,
  ExternalImageInput second, {
  required bool adjacent,
}) {
  if (!first.isAccepted ||
      !second.isAccepted ||
      first.source != second.source ||
      !_isFileAndMemoryPair(first, second)) {
    return false;
  }
  // Clipboard readers emit an original file before its rendered bitmap.
  // Keep the direction significant: a bitmap followed by an unrelated file
  // represents two images and must retain both entries.
  if (adjacent &&
      first.source == ExternalImageInputSource.clipboard &&
      _isFileInput(first) &&
      second.kind == ExternalImageInputKind.memory) {
    return true;
  }
  final firstName = _candidateStem(first);
  final secondName = _candidateStem(second);
  return firstName != null && secondName != null && firstName == secondName;
}

bool _isFileAndMemoryPair(
  ExternalImageInput first,
  ExternalImageInput second,
) {
  return (_isFileInput(first) &&
          second.kind == ExternalImageInputKind.memory) ||
      (_isFileInput(second) && first.kind == ExternalImageInputKind.memory);
}

bool _isFileInput(ExternalImageInput input) {
  return switch (input.kind) {
    ExternalImageInputKind.filePath || ExternalImageInputKind.fileUri => true,
    ExternalImageInputKind.memory => false,
  };
}

bool _hasPixelSize(ExternalImageBlockDescription description) {
  final width = description.width;
  final height = description.height;
  return width != null && height != null && width > 0 && height > 0;
}

bool _shouldUseFallbackPixelSize(
  ExternalImageBlockDescription description,
  ExternalImagePixelSize? fallbackPixelSize,
) {
  if (fallbackPixelSize == null) {
    return false;
  }
  if (!_hasPixelSize(description)) {
    return true;
  }
  final currentRatio = description.width! / description.height!;
  final fallbackRatio = fallbackPixelSize.width / fallbackPixelSize.height;
  return (currentRatio - fallbackRatio).abs() > 0.001;
}

ExternalImageBlockDescription _withPixelSize(
  ExternalImageBlockDescription description,
  ExternalImagePixelSize pixelSize,
) {
  return ExternalImageBlockDescription(
    file: description.file,
    caption: description.caption,
    altText: description.altText,
    width: pixelSize.width,
    height: pixelSize.height,
  );
}

ExternalImageBlockDescription _withDimensions(
  ExternalImageBlockDescription description,
  ExternalImageBlockDescription dimensionsSource,
) {
  return ExternalImageBlockDescription(
    file: description.file,
    caption: description.caption,
    altText: description.altText,
    width: dimensionsSource.width,
    height: dimensionsSource.height,
  );
}

String? _candidateStem(ExternalImageInput input) {
  final normalized = externalImageDisplayName(input).trim().toLowerCase();
  if (normalized.isEmpty ||
      normalized == defaultExternalImageCaption.toLowerCase()) {
    return null;
  }
  return normalized;
}
