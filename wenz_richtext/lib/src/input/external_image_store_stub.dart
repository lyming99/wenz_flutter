import 'external_image_input.dart';

/// Creates a no-op store for platforms without filesystem-backed image input.
ExternalImageStore createDefaultExternalImageStore() =>
    const ExternalImageStubStore();

/// Stub implementation used by non-IO platforms.
class ExternalImageStubStore implements ExternalImageStore {
  const ExternalImageStubStore();

  @override
  Future<ExternalImageStoreResult> prepare(ExternalImageInput input) async {
    final rejection = input.rejection;
    if (rejection != null) {
      return ExternalImageStoreResult.failure(rejection);
    }
    return const ExternalImageStoreResult.failure(
      ExternalImageInputRejection(
        reason: ExternalImageInputRejectionReason.unsupportedPlatform,
        message: 'External image storage is not available on this platform.',
      ),
    );
  }
}
