import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'id_generator.g.dart';

/// Creates primary keys. UUIDv7 ids are unique across devices (sync-ready)
/// and roughly time-ordered, but never sort rows by id: use timestamps.
abstract interface class IdGenerator {
  String newId();
}

final class UuidV7Generator implements IdGenerator {
  UuidV7Generator() : _uuid = const Uuid();

  final Uuid _uuid;

  @override
  String newId() => _uuid.v7();
}

/// Deterministic ids for tests: `id-1`, `id-2`, …
final class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator({this.prefix = 'id'});

  final String prefix;
  int _next = 1;

  @override
  String newId() => '$prefix-${_next++}';
}

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => UuidV7Generator();
