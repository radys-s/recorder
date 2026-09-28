import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recorder/app.dart';
import 'package:recorder/core/providers.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/data/db/tables/preferences_table.dart';
import 'package:recorder/legal/legal_texts.dart';

void main() {
  testWidgets('RecorderApp builds without throwing', (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Terms already agreed, so the consent gate lets the app through.
          preferencesProvider.overrideWith(
            (ref) => Stream.value(
              Preference(
                id: 0,
                transcriptLanguage: TranscriptLanguage.czech,
                notesDepth: NotesDepth.standard,
                accentPreset: AccentPreset.gold,
                liveAnswersEnabled: false,
                webAnswersEnabled: false,
                micSensitivity: MicSensitivity.auto,
                onboardingDismissed: true,
                contextCorrection: true,
                audioRetention: AudioRetention.sevenDays,
                lessonReminder: LessonReminder.off,
                driveSyncEnabled: false,
                driveIncludeTranscripts: false,
                termsAcceptedVersion: kTermsVersion,
                recordingNoticeDismissed: false,
              ),
            ),
          ),
        ],
        child: const RecorderApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    final library = tester.getSemantics(find.bySemanticsLabel('Knihovna'));
    expect(library.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });
}
