import 'package:flutter/foundation.dart';

class DevAuthConfig {
  const DevAuthConfig._();

  static const _allowEmulatorLogin = bool.fromEnvironment(
    'ALLOW_EMULATOR_LOGIN',
  );

  static bool get allowEmulatorLogin => kDebugMode && _allowEmulatorLogin;
}
