import 'package:coin_pilot/src/core/ai/ai_failure.dart';
import 'package:coin_pilot/src/core/ai/ai_token_source.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Reads the anonymous user's ID token and the App Check token.
final class FirebaseTokenSource implements AiTokenSource {
  FirebaseTokenSource({FirebaseAuth? auth, FirebaseAppCheck? appCheck})
    : _auth = auth ?? FirebaseAuth.instance,
      _appCheck = appCheck ?? FirebaseAppCheck.instance;

  final FirebaseAuth _auth;
  final FirebaseAppCheck _appCheck;

  @override
  Future<String> idToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user;
    final token = await user?.getIdToken(forceRefresh);
    if (token == null) {
      throw const AiFailure(AiErrorCode.unauthenticated, message: 'No Firebase user');
    }
    return token;
  }

  @override
  Future<String?> appCheckToken() => _appCheck.getToken();
}
