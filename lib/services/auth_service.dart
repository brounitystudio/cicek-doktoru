import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'dev_auth_config.dart';
import 'firebase_bootstrap.dart';

const _googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue:
      '949168519770-u4p5ca4m0pi83jfca7ksvn2uv6056a99.apps.googleusercontent.com',
);

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth,
      _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            scopes: const ['email', 'profile'],
            serverClientId: _googleServerClientId,
          );

  final FirebaseAuth? _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;

  User? get currentUser {
    try {
      return _auth.currentUser;
    } on FirebaseException {
      return null;
    }
  }

  bool get hasSignedInUser {
    final user = currentUser;
    return user != null &&
        (!user.isAnonymous || DevAuthConfig.allowEmulatorLogin);
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      final firebaseReady = await FirebaseBootstrap.ensureInitialized();
      if (!firebaseReady) {
        throw const AuthException('Firebase bağlantısı hazır değil.');
      }

      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const AuthException(
          'Google hesap seçimi tamamlanmadı. Hesabını seçip tekrar deneyebilirsin.',
        );
      }

      final authentication = await account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null) {
        throw const AuthException('Google oturumu doğrulanamadı.');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: authentication.accessToken,
        idToken: idToken,
      );
      return _auth.signInWithCredential(credential);
    } on AuthException {
      rethrow;
    } on PlatformException catch (error, stackTrace) {
      debugPrint('Google sign-in failed: ${error.code} ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
      throw AuthException(_googleSignInErrorMessage(error));
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseAuthErrorMessage(error));
    }
  }

  Future<UserCredential> signInWithApple() async {
    try {
      final firebaseReady = await FirebaseBootstrap.ensureInitialized();
      if (!firebaseReady) {
        throw const AuthException('Firebase bağlantısı hazır değil.');
      }

      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      return _auth.signInWithProvider(provider);
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'web-context-cancelled' ||
          error.code == 'canceled' ||
          error.code == 'popup-closed-by-user') {
        throw const AuthException(
          'Apple ile giriş tamamlanmadı. Tekrar deneyebilirsin.',
        );
      }
      throw AuthException(_firebaseAuthErrorMessage(error));
    }
  }

  Future<UserCredential> signInWithEmulatorTestUser() async {
    if (!DevAuthConfig.allowEmulatorLogin) {
      throw const AuthException('Emülatör test girişi bu build içinde kapalı.');
    }

    final firebaseReady = await FirebaseBootstrap.ensureInitialized();
    if (!firebaseReady) {
      throw const AuthException('Firebase bağlantısı hazır değil.');
    }

    return _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (error) {
      debugPrint('Google disconnect skipped: $error');
    }
    await _auth.signOut();
  }

  Future<void> deleteCurrentAccount() async {
    final firebaseReady = await FirebaseBootstrap.ensureInitialized();
    if (!firebaseReady || currentUser == null) {
      throw const AuthException('Silinecek oturum bulunamadı.');
    }

    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('deleteCurrentUserAccount').call<Map<String, dynamic>>();
      await _auth.signOut();
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Account deletion failed: ${error.code} ${error.message}');
      throw const AuthException(
        'Hesap şu anda silinemedi. İnternet bağlantını kontrol edip tekrar dene.',
      );
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _googleSignInErrorMessage(PlatformException error) {
  return switch (error.code) {
    'sign_in_canceled' || 'canceled' =>
      'Google hesap seçimi tamamlanmadı. Hesabını seçip tekrar deneyebilirsin.',
    'network_error' =>
      'İnternet bağlantısı zayıf görünüyor. Bağlantını kontrol edip tekrar dene.',
    'sign_in_failed' when (error.message ?? '').contains('10:') =>
      'Google giriş ayarları cihaz imzasıyla eşleşmiyor. Lütfen uygulamayı güncel sürümle tekrar dene.',
    'sign_in_failed' =>
      'Google ile giriş şu anda tamamlanamadı. Lütfen tekrar dene.',
    'ui_unavailable' =>
      'Bu cihazda Google giriş ekranı açılamadı. Google Play hizmetleri olan bir cihazda tekrar dene.',
    'client_configuration_error' || 'provider_configuration_error' =>
      'Google giriş ayarlarında bir eksik var. Lütfen uygulamayı güncel sürümle tekrar dene.',
    'interrupted' =>
      'Google girişi yarıda kesildi. Birazdan tekrar deneyebilirsin.',
    _ => 'Google ile giriş şu anda tamamlanamadı. Lütfen tekrar dene.',
  };
}

String _firebaseAuthErrorMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'network-request-failed' =>
      'İnternet bağlantısı zayıf görünüyor. Bağlantını kontrol edip tekrar dene.',
    'account-exists-with-different-credential' =>
      'Bu e-posta farklı bir giriş yöntemiyle kayıtlı görünüyor.',
    'invalid-credential' || 'credential-already-in-use' =>
      'Oturum doğrulanamadı. Lütfen tekrar giriş yap.',
    'operation-not-allowed' =>
      'Bu giriş yöntemi henüz etkin değil. Lütfen uygulamayı güncelleyip tekrar dene.',
    _ => 'Giriş şu anda tamamlanamadı. Lütfen tekrar dene.',
  };
}
