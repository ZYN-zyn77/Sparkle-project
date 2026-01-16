import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:opentelemetry/web_sdk.dart' as web_sdk;

sdk.TracerProviderBase createTracerProvider(List<sdk.SpanProcessor> processors) {
  return web_sdk.WebTracerProvider(
    processors: processors,
    timeProvider: web_sdk.WebTimeProvider(),
  );
}