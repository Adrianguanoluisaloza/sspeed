import 'maps_script_loader_stub.dart'
    if (dart.library.html) 'maps_script_loader_web.dart' as loader;

Future<void> ensureGoogleMapsScriptLoaded(String apiKey) =>
    loader.ensureGoogleMapsScriptLoaded(apiKey);

bool get isGoogleMapsScriptLoaded => loader.isGoogleMapsScriptLoaded;
