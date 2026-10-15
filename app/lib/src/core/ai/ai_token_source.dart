/// Supplies the credentials every proxy call needs (ADR 0002).
abstract interface class AiTokenSource {
  /// Firebase ID token of the (anonymous) user, refreshed when [forceRefresh].
  Future<String> idToken({bool forceRefresh = false});

  /// App Check token proving the request comes from the genuine app.
  Future<String?> appCheckToken();
}
