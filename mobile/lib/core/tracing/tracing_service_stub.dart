import 'package:opentelemetry/sdk.dart' as sdk;

sdk.TracerProviderBase createTracerProvider(List<sdk.SpanProcessor> processors) {
  throw UnsupportedError('Cannot create a tracer provider without dart:html or dart:io');
}