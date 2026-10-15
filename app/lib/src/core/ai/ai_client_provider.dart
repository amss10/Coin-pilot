import 'package:cloud_functions/cloud_functions.dart';
import 'package:coin_pilot/src/core/ai/ai_client.dart';
import 'package:coin_pilot/src/core/ai/chat_sse_transport.dart';
import 'package:coin_pilot/src/core/ai/fake_ai_client.dart';
import 'package:coin_pilot/src/core/ai/firebase_ai_client.dart';
import 'package:coin_pilot/src/core/config/env.dart';
import 'package:coin_pilot/src/core/firebase/firebase_setup.dart';
import 'package:coin_pilot/src/core/firebase/firebase_token_source.dart';
import 'package:coin_pilot/src/core/ids/id_generator.dart';
import 'package:coin_pilot/src/core/time/clock_provider.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_client_provider.g.dart';

/// The AI client for the configured backend (`AI_BACKEND` in env/*.json).
@Riverpod(keepAlive: true)
AiClient aiClient(Ref ref) {
  final env = ref.watch(envConfigProvider);
  switch (env.aiBackend) {
    case AiBackend.fake:
      return FakeAiClient(
        clock: ref.watch(appClockProvider),
        chatChunkDelay: const Duration(milliseconds: 25),
      );
    case AiBackend.firebase:
      final httpClient = http.Client();
      ref.onDispose(httpClient.close);
      return FirebaseAiClient(
        functions: FirebaseFunctions.instanceFor(region: env.functionsRegion),
        chatTransport: ChatSseTransport(
          client: httpClient,
          endpoint: chatEndpoint(env),
          tokens: FirebaseTokenSource(),
          appVersion: env.appVersion,
        ),
        ids: ref.watch(idGeneratorProvider),
        appVersion: env.appVersion,
      );
  }
}
