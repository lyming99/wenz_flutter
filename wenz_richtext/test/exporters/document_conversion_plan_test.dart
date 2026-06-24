import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('WenzDocumentConversionPlan', () {
    test('keeps PDF export outside core runtime dependencies', () {
      final plan = wenzDocumentConversionPlanFor(
        WenzDocumentFormat.pdf,
        WenzDocumentConversionDirection.exportDocument,
      );

      expect(plan, same(wenzPdfExportPlan));
      expect(plan.isCoreProvided, isFalse);
      expect(plan.requiresExternalAdapter, isTrue);
      expect(plan.keepsCoreDependencyFree, isTrue);
      expect(
        plan.dependencyBoundaries,
        containsAll(<WenzDocumentDependencyBoundary>{
          WenzDocumentDependencyBoundary.appOwnedPlatformPlugin,
          WenzDocumentDependencyBoundary.platformPrintPipeline,
          WenzDocumentDependencyBoundary.serverWorker,
        }),
      );
      expect(
        plan.degradationBoundaries,
        contains(WenzDocumentDegradationBoundary.fixedLayoutIsNotEditable),
      );
    });

    test('declares PDF import as unsupported fixed-layout conversion', () {
      final plan = wenzDocumentConversionPlanFor(
        WenzDocumentFormat.pdf,
        WenzDocumentConversionDirection.importDocument,
      );

      expect(plan.isUnsupported, isTrue);
      expect(plan.requiresExternalAdapter, isFalse);
      expect(plan.platforms, isEmpty);
      expect(
        plan.degradationBoundaries,
        contains(WenzDocumentDegradationBoundary.pdfImportIsNotReliable),
      );
    });

    test('keeps DOCX import and export adapter-owned', () {
      final exportPlan = wenzDocumentConversionPlanFor(
        WenzDocumentFormat.docx,
        WenzDocumentConversionDirection.exportDocument,
      );
      final importPlan = wenzDocumentConversionPlanFor(
        WenzDocumentFormat.docx,
        WenzDocumentConversionDirection.importDocument,
      );

      for (final plan in <WenzDocumentConversionPlan>[
        exportPlan,
        importPlan,
      ]) {
        expect(plan.owner, WenzDocumentConversionOwner.applicationAdapter);
        expect(plan.requiresExternalAdapter, isTrue);
        expect(plan.keepsCoreDependencyFree, isTrue);
        expect(
          plan.platforms,
          containsAll(<WenzDocumentConversionPlatform>{
            WenzDocumentConversionPlatform.android,
            WenzDocumentConversionPlatform.ios,
            WenzDocumentConversionPlatform.macos,
            WenzDocumentConversionPlatform.windows,
            WenzDocumentConversionPlatform.linux,
            WenzDocumentConversionPlatform.web,
            WenzDocumentConversionPlatform.server,
          }),
        );
        expect(
          plan.degradationBoundaries,
          containsAll(<WenzDocumentDegradationBoundary>{
            WenzDocumentDegradationBoundary.unsupportedEmbedsBecomeReadableText,
            WenzDocumentDegradationBoundary.attachmentsBecomeLinks,
            WenzDocumentDegradationBoundary.commentsAndRevisionsStayExternal,
          }),
        );
      }
    });

    test('allows host applications to implement typed adapters', () async {
      final exporter = _PlainTextBytesExporter();
      final output = await exporter.exportDocument(
        const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Hello PDF')],
            ),
          ],
        ),
      );

      expect(exporter.plan, same(wenzPdfExportPlan));
      expect(output, 'Hello PDF'.codeUnits);
    });
  });
}

class _PlainTextBytesExporter implements WenzDocumentExporter<List<int>> {
  @override
  WenzDocumentConversionPlan get plan => wenzPdfExportPlan;

  @override
  Future<List<int>> exportDocument(RichTextDocument document) async {
    return document.plainText.codeUnits;
  }
}
