import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'env.g.dart';

enum AppFlavor { dev, prod }

/// Which AI backend the app talks to.
enum AiBackend {
  /// Deterministic offline fake (default for development and tests).
  fake,

  /// The Firebase Cloud Functions proxy.
  firebase,
}

/// Compile-time configuration from `--dart-define-from-file=env/<flavor>.json`.
@immutable
final class EnvConfig {
  const EnvConfig({
    this.flavor = AppFlavor.dev,
    this.aiBackend = AiBackend.fake,
    this.functionsRegion = 'us-central1',
    this.useFirebaseEmulators = false,
    this.emulatorHost = '10.0.2.2',
    this.seedDemoData = false,
    this.appCheckDebugToken = '',
    this.appVersion = '0.1.0+1',
  });

  factory EnvConfig.fromEnvironment() => const EnvConfig(
    flavor: String.fromEnvironment('APP_FLAVOR') == 'prod' ? AppFlavor.prod : AppFlavor.dev,
    aiBackend: String.fromEnvironment('AI_BACKEND') == 'firebase'
        ? AiBackend.firebase
        : AiBackend.fake,
    functionsRegion: String.fromEnvironment('FUNCTIONS_REGION', defaultValue: 'us-central1'),
    useFirebaseEmulators: bool.fromEnvironment('USE_FIREBASE_EMULATORS'),
    emulatorHost: String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2'),
    seedDemoData: bool.fromEnvironment('SEED_DEMO_DATA'),
    appCheckDebugToken: String.fromEnvironment('APP_CHECK_DEBUG_TOKEN'),
    appVersion: String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0+1'),
  );

  final AppFlavor flavor;
  final AiBackend aiBackend;
  final String functionsRegion;
  final bool useFirebaseEmulators;
  final String emulatorHost;
  final bool seedDemoData;

  /// App Check debug token for emulators/CI. Keep it in `env/*.local.json`.
  final String appCheckDebugToken;
  final String appVersion;

  bool get usesFirebase => aiBackend == AiBackend.firebase;
}

/// Overridden in `bootstrap.dart` with [EnvConfig.fromEnvironment].
@Riverpod(keepAlive: true)
EnvConfig envConfig(Ref ref) => const EnvConfig();
