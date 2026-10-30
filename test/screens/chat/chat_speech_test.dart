import 'package:ell_ena/screens/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import 'speech_mock.dart';

// `SpeechToText` is a process-wide singleton that remembers a successful
// `initialize`, so the "not available" case runs first.
void main() {
  setUpAll(setUpFakeSupabase);
  setUp(resetFakeSupabase);

  // Opened as a pushed route, as from the Calendar, so popping the wrong
  // route would close the chat screen.
  Future<PushedResult> pumpChat(WidgetTester tester) async {
    final result = await pumpPushed(tester, const ChatScreen());
    await settle(tester);
    return result;
  }

  String inputText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  final listeningDialog = find.text('Listening...');

  testWidgets('without speech support the mic explains why', (tester) async {
    mockSpeech(available: false);
    await pumpChat(tester);

    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();

    expect(
      find.text('Speech recognition not available on this device'),
      findsOneWidget,
    );
    expect(speechCalls, isNot(contains('listen')));
  });

  // The plugin keeps the status and error listeners of the first screen that
  // initialised it, so every dictation flow runs on one screen.
  testWidgets('dictation: results, completion, cancel, stop and errors',
      (tester) async {
    mockSpeech(available: true);
    final chatRoute = await pumpChat(tester);
    int stops() => speechCalls.where((c) => c == 'stop').length;

    // Words fill the input; the plugin finishing closes the dialog.
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    expect(listeningDialog, findsOneWidget);
    expect(find.text('Tap anywhere to cancel'), findsOneWidget);
    expect(speechCalls, contains('listen'));
    expect(find.byTooltip('Stop listening'), findsOneWidget);
    await sendSpeechEvent('textRecognition', speechResult('book a room'));
    await tester.pump();
    expect(inputText(tester), 'book a room');
    await sendSpeechEvent('notifyStatus', 'notListening');
    await tester.pump(const Duration(milliseconds: 500));
    expect(listeningDialog, findsNothing);
    expect(find.byTooltip('Voice input'), findsOneWidget);
    // The plugin also reports "done"; only the dialog was closed.
    await sendSpeechEvent('notifyStatus', 'done');
    await tester.pump(const Duration(milliseconds: 500));
    expect(chatRoute.popped, isFalse);
    expect(find.byType(ChatScreen), findsOneWidget);

    // Dismissing the dialog while listening stops the session.
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    await sendSpeechEvent('notifyStatus', 'listening');
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 500));
    expect(listeningDialog, findsNothing);
    expect(stops(), 1);
    // The plugin then reports it stopped; the chat screen stays open.
    await sendSpeechEvent('notifyStatus', 'notListening');
    await tester.pump(const Duration(milliseconds: 500));
    expect(chatRoute.popped, isFalse);
    expect(find.byType(ChatScreen), findsOneWidget);

    // Dismissed before the plugin started: nothing to stop yet. Once it
    // reports listening, the mic button stops it.
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 500));
    expect(stops(), 1);
    await sendSpeechEvent('notifyStatus', 'listening');
    await tester.pump();
    await tester.tap(find.byTooltip('Stop listening'));
    await tester.pump();
    expect(stops(), 2);
    expect(find.byTooltip('Voice input'), findsOneWidget);

    // A recognition error closes the dialog.
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    await sendSpeechEvent(
      'notifyError',
      '{"errorMsg":"error_network","permanent":true}',
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(listeningDialog, findsNothing);
    expect(find.byTooltip('Voice input'), findsOneWidget);
    expect(chatRoute.popped, isFalse);

    // Leaving the screen mid-session stops it.
    await sendSpeechEvent('notifyStatus', 'listening');
    await tester.pumpWidget(const SizedBox());
    expect(stops(), greaterThan(2));
    // The plugin waits briefly for a final result after stopping.
    await tester.pump(const Duration(seconds: 3));
  });
}
