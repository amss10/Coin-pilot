import 'package:cloud_functions/cloud_functions.dart';
import 'package:coin_pilot/firebase_options.dart';
import 'package:coin_pilot/src/core/config/env.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Initialises Firebase for the AI proxy (only when `AI_BACKEND=firebase`).
///
/// Order matters: App Check must be active before the first callable or
/// sign-in request so every request carries an attestation token.
Future<void> initFirebase(EnvConfig env, {required bool crashReportingOptIn}) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final useDebugProvider = env.useFirebaseEmulators || kDebugMode;
  final debugToken = env.appCheckDebugToken.isEmpty ? null : env.appCheckDebugToken;
  await FirebaseAppCheck.instance.activate(
    providerAndroid: useDebugProvider
        ? AndroidDebugProvider(debugToken: debugToken)
        : const AndroidPlayIntegrityProvider(),
    providerApple: useDebugProvider
        ? AppleDebugProvider(debugToken: debugToken)
        : const AppleAppAttestWithDeviceCheckFallbackProvider(),
  );

  if (env.useFirebaseEmulators) {
    await FirebaseAuth.instance.useAuthEmulator(env.emulatorHost, 9099);
    FirebaseFunctions.instanceFor(region: env.functionsRegion)
        .useFunctionsEmulator(env.emulatorHost, 5001);
  }

  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    crashReportingOptIn && !kDebugMode,
  );
}

/// URL of the chat SSE function (contract §2).
Uri chatEndpoint(EnvConfig env) {
  final projectId = Firebase.app().options.projectId;
  if (env.useFirebaseEmulators) {
    return Uri.parse('http://${env.emulatorHost}:5001/$projectId/${env.functionsRegion}/chat');
  }
  return Uri.parse('https://${env.functionsRegion}-$projectId.cloudfunctions.net/chat');
}
