import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('plugin.csdcorp.com/speech_to_text');

/// Calls `ChatScreen` made to the speech plugin, by method name.
final List<String> speechCalls = [];

/// Answers the `speech_to_text` plugin channel. [available] is what
/// `initialize` reports.
void mockSpeech({bool available = false}) {
  speechCalls.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
    speechCalls.add(call.method);
    switch (call.method) {
      case 'initialize':
        return available;
      case 'has_permission':
        return available;
      case 'listen':
        return true;
      case 'locales':
        return <String>[];
      default:
        return null;
    }
  });
}

/// Delivers a platform callback (`notifyStatus`, `textRecognition`, ...) as
/// the plugin would.
Future<void> sendSpeechEvent(String method, Object arguments) {
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    _channel.name,
    _channel.codec.encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  );
}

/// A recognition result in the plugin's JSON format.
String speechResult(String words, {bool isFinal = false}) => jsonEncode({
      'alternates': [
        {'recognizedWords': words, 'confidence': 0.9}
      ],
      'finalResult': isFinal,
    });
