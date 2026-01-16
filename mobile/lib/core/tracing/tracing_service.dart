import 'package:flutter/foundation.dart';
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:uuid/uuid.dart';

import 'tracing_service_stub.dart'
    if (dart.library.io) 'tracing_service_mobile.dart'
    if (dart.library.html) 'tracing_service_web.dart';

class TracingService {
  TracingService._internal();

  static final TracingService instance = TracingService._internal();

  final Uuid _uuid = const Uuid();
  bool _initialized = false;

  Future<void> initialize({Uri? collectorUri}) async {
    if (_initialized) return;

    final processors = <sdk.SpanProcessor>[];
    if (collectorUri != null) {
      processors.add(
        sdk.BatchSpanProcessor(sdk.CollectorExporter(collectorUri)),
      );
    }
    if (kDebugMode) {
      processors.add(sdk.SimpleSpanProcessor(sdk.ConsoleExporter()));
    }

    final tracerProvider = createTracerProvider(processors);
    api.registerGlobalTracerProvider(tracerProvider);
    _initialized = true;
  }

  api.Span startSpan(String name) => api.globalTracerProvider.getTracer('sparkle-mobile').startSpan(name);

  String createTraceId({String spanName = 'trace.generate'}) {
    if (!_initialized) {
      return _uuid.v4();
    }
    final span = startSpan(spanName);
    final traceId = span.spanContext.traceId;
    span.end();
    return traceId.toString();
  }

  void recordException(api.Span span, Object error, StackTrace stackTrace) {
    span
      ..recordException(error, stackTrace: stackTrace)
      ..setStatus(api.StatusCode.error, error.toString());
  }
}
