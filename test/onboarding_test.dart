import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recorder/features/meetings_list/widgets/onboarding_card.dart';

void main() {
  test('only the Groq key and a subject are required', () {
    final none = onboardingSteps(
      hasGroqKey: false,
      hasGeminiKey: false,
      hasSubject: false,
      hasStudyProfile: false,
      hasTimetable: false,
    );
    expect(onboardingRequiredDone(none), isFalse);
    expect(none.where((s) => s.optional).map((s) => s.step), [
      OnboardingStep.geminiKey,
      OnboardingStep.study,
      OnboardingStep.timetable,
    ]);

    final required = onboardingSteps(
      hasGroqKey: true,
      hasGeminiKey: false,
      hasSubject: true,
      hasStudyProfile: false,
      hasTimetable: false,
    );
    expect(onboardingRequiredDone(required), isTrue);

    final keyOnly = onboardingSteps(
      hasGroqKey: true,
      hasGeminiKey: true,
      hasSubject: false,
      hasStudyProfile: false,
      hasTimetable: true,
    );
    expect(onboardingRequiredDone(keyOnly), isFalse);
  });

  testWidgets('the card counts steps and opens only unfinished ones', (
    tester,
  ) async {
    final tapped = <OnboardingStep>[];
    var closed = false;
    Future<void> pump(List<OnboardingItem> steps) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OnboardingCard(
              steps: steps,
              onStep: tapped.add,
              onClose: () => closed = true,
            ),
          ),
        ),
      ),
    );

    await pump(
      onboardingSteps(
        hasGroqKey: true,
        hasGeminiKey: false,
        hasSubject: false,
        hasStudyProfile: false,
        hasTimetable: false,
      ),
    );
    expect(find.text('Začínáme'), findsOneWidget);
    expect(find.text('1 z 5 kroků'), findsOneWidget);

    await tester.tap(find.text('Vlož Groq klíč'));
    await tester.tap(find.text('Založ první předmět'));
    expect(tapped, [OnboardingStep.subject]);

    await tester.tap(find.text('Skrýt'));
    expect(closed, isTrue);

    await pump(
      onboardingSteps(
        hasGroqKey: true,
        hasGeminiKey: false,
        hasSubject: true,
        hasStudyProfile: false,
        hasTimetable: false,
      ),
    );
    expect(find.text('Hotovo, můžeš nahrávat'), findsOneWidget);
    expect(find.text('Zavřít'), findsOneWidget);
  });
}
