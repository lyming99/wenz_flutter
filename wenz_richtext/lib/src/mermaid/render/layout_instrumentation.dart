import 'dart:async';

/// Accumulates text-measurement work nested inside a layout operation.
class MermaidTextMeasurementCollector {
  Duration duration = Duration.zero;

  void add(Duration value) {
    duration += value;
  }
}

final Object _collectorZoneKey = Object();

T collectMermaidTextMeasurements<T>(
  MermaidTextMeasurementCollector collector,
  T Function() body,
) {
  return runZoned<T>(
    body,
    zoneValues: <Object, Object>{_collectorZoneKey: collector},
  );
}

void recordMermaidTextMeasurement(Duration duration) {
  final collector = Zone.current[_collectorZoneKey];
  if (collector is MermaidTextMeasurementCollector) {
    collector.add(duration);
  }
}
