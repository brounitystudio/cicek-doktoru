import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static bool _initialized = false;

  static Future<bool> ensureInitialized() async {
    if (_initialized) {
      return true;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      return true;
    } catch (error) {
      debugPrint('Firebase config is not ready yet: $error');
      return false;
    }
  }
}
