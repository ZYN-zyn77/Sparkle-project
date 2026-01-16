import 'package:opentelemetry/sdk.dart' as sdk;

sdk.TracerProviderBase createTracerProvider(List<sdk.SpanProcessor> processors) {
  return sdk.TracerProviderBase(processors: processors);
}