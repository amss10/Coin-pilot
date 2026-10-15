import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_lock_service.g.dart';

/// Device authentication (biometrics with device PIN/pattern fallback).
abstract interface class AppLockService {
  /// Whether the device has a screen lock or biometrics we can use.
  Future<bool> isAvailable();

  /// Shows the system prompt; true when the user authenticated.
  Future<bool> authenticate(String reason);
}

final class LocalAuthAppLockService implements AppLockService {
  LocalAuthAppLockService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
AppLockService appLockService(Ref ref) => LocalAuthAppLockService();
