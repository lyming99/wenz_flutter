# Generated draw.io stencil drafts

This directory is intentionally for generated, review-before-merge artifacts.

Typical workflow:

```powershell
dart run tool/drawio_stencil_extract.dart `
  --input D:\project\GitHub\drawio\src\main\webapp\stencils\bpmn.xml `
  --library bpmn `
  --group BPMN `
  --out-manifest tool\generated_stencils\bpmn_manifest.json `
  --out-dart tool\generated_stencils\bpmn_stencils.dart

dart run tool/drawio_stencil_manifest.dart tool\generated_stencils\bpmn_manifest.json
```

The manifest contains metadata only:

- `library`, `group`, `shapeCount`, `sourceFile`, `sourceSizeBytes`, `generatedAt`
- per shape: `key`, `label`, `group`, `sourceFile`, `defaultWidth`, `defaultHeight`, `tags`, `aliases`

Generated Dart drafts contain `keys`, `labels`, `aliases`, and `xmlDefinitions` and can be reviewed before being moved into `lib/src/stencils/libraries/`.

Current generated artifacts:

| Manifest | Shapes | Notes |
| --- | ---: | --- |
| `bpmn_manifest.json` | 39 | Small; also has `bpmn_stencils.dart` draft. |
| `aws4_manifest.json` | 1037 | Very large; lazy loading recommended. |
| `gcp2_manifest.json` | 297 | Large; lazy loading recommended. |
| `alibaba_cloud_manifest.json` | 310 | Large; lazy loading recommended. |
| `cisco19_manifest.json` | 232 | Medium; needs registration benchmark. |
| `networks2_manifest.json` | 115 | Medium; possible network-library pilot. |
| `webicons_manifest.json` | 176 | Medium; confirm rendering quality and licensing. |
| `weblogos_manifest.json` | 178 | Medium; confirm trademark/licensing risk. |

Generated Dart files should not be moved into `lib/src/stencils/libraries/` without review:

- confirm licensing and package-size impact;
- decide eager vs lazy registration;
- run parser / renderer / SVG export smoke tests;
- design palette grouping and search UX for large libraries.
