// Placeholder until the Firebase project exists (roadmap phase 2).
// Replace this file by running, from app/:
//   flutterfire configure --project=<project-id> --platforms=android,ios \
//     --android-package-name=org.fekrahouse.coinpilot --ios-bundle-id=org.fekrahouse.coinpilot
// The default dev configuration (AI_BACKEND=fake) never calls this.
import 'package:firebase_core/firebase_core.dart';

abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase is not configured yet. Run `flutterfire configure` (see README.md) '
    'or use AI_BACKEND=fake.',
  );
}
