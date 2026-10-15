import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

/// One Server-Sent Event.
@immutable
final class SseEvent {
  const SseEvent(this.event, this.data);

  /// Event name (`message` when the stream doesn't name it).
  final String event;
  final String data;

  @override
  bool operator ==(Object other) => other is SseEvent && other.event == event && other.data == data;

  @override
  int get hashCode => Object.hash(event, data);

  @override
  String toString() => 'SseEvent($event, $data)';
}

/// Parses a `text/event-stream` byte stream (UTF-8) per the HTML spec:
/// `event:` / `data:` fields, multi-line data joined with `\n`, comment lines
/// (starting with `:`) ignored, events dispatched on a blank line. An event
/// left unterminated when the stream ends is discarded.
Stream<SseEvent> parseSse(Stream<List<int>> bytes) async* {
  var eventName = 'message';
  final data = StringBuffer();
  var hasData = false;

  final lines = bytes.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.isEmpty) {
      if (hasData) yield SseEvent(eventName, data.toString());
      eventName = 'message';
      data.clear();
      hasData = false;
      continue;
    }
    if (line.startsWith(':')) continue;

    final colon = line.indexOf(':');
    final field = colon == -1 ? line : line.substring(0, colon);
    var value = colon == -1 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);

    switch (field) {
      case 'event':
        eventName = value;
      case 'data':
        if (hasData) data.write('\n');
        data.write(value);
        hasData = true;
      default:
        // `id` and `retry` are not used by the chat protocol.
        break;
    }
  }
}
