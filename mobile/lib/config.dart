/// Address of the Flask backend (see backend/ in the repository root).
///
/// Override it at run/build time instead of editing code, e.g.
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5000/flutter
/// From the Android emulator the host machine is http://10.0.2.2:5000/flutter.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:5000/flutter',
);
