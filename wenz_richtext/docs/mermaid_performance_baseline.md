# Mermaid native rendering baseline

Recorded on 2026-08-06 with Flutter 3.41.2 / Dart 3.11.0 on Windows x64,
using the debug Flutter test runner. The probe records only cardinalities and
timings; it never prints Mermaid source text or source digests.

Run the repeatable probe with:

```powershell
flutter test --no-pub --reporter expanded test/mermaid/mermaid_performance_test.dart
```

Representative result from the implementation baseline:

| Workload | Parse | Layout | Text measurement | Total |
| --- | ---: | ---: | ---: | ---: |
| 10 nodes / 9 edges (cold worker start) | 34.873 ms | 22.389 ms | 3.002 ms | 82.289 ms |
| 100 nodes / 99 edges | 4.538 ms | 4.449 ms | 0.155 ms | 11.077 ms |
| 500 nodes / 499 edges | 16.814 ms | 20.018 ms | 0.239 ms | 39.526 ms |

The 100-node / 150-edge warm-cache P95 was 0.421 ms over 20 samples. The
measured synchronous scheduling portion of a warm request was 0.441 ms. Both
are below the release goals of 250 ms warm P95 and 8 ms synchronous UI-isolate
occupancy. Numbers are diagnostic baselines rather than cross-machine golden
values; CI asserts the published upper bounds and finite geometry.
