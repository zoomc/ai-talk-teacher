import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/chat/domain/chat_models.dart';
import 'package:speakflow/features/chat/domain/tutor.dart';
import 'package:speakflow/features/chat/domain/tutor_prompts.dart';

void main() {
  group('TutorPromptBuilder.build', () {
    test('returns a non-empty prompt with the pedagogical spine', () {
      final prompt = TutorPromptBuilder.build();
      expect(prompt, isNotEmpty);
      // Spine should always mention something pedagogy-related, regardless
      // of which optional blocks are added.
      expect(prompt.toLowerCase(), contains('tutor'));
    });

    test('includes the tutor persona when a tutor is provided', () {
      final tutor = TutorRepository.getDefaultTutor(); // Emma
      final prompt = TutorPromptBuilder.build(tutor: tutor);
      expect(prompt, contains('## Your persona'));
      expect(prompt, contains(tutor.systemPrompt));
    });

    test('does not include persona section when tutor is null', () {
      final prompt = TutorPromptBuilder.build();
      expect(prompt, isNot(contains('## Your persona')));
    });

    test('includes scenario context when a scenario is provided', () {
      final scenario = Scenario(
        name: 'Ordering at a cafe',
        description: 'Practice ordering coffee.',
        icon: '☕',
        difficulty: 'beginner',
        category: 'daily',
        systemPrompt: 'You are the barista. The student is a customer.',
      );
      final prompt = TutorPromptBuilder.build(scenario: scenario);
      expect(prompt, contains('## Scenario'));
      expect(prompt, contains('Ordering at a cafe'));
      expect(prompt, contains('barista'));
    });

    test('falls back to topic block when no scenario but a topic is given', () {
      final prompt = TutorPromptBuilder.build(sessionTopic: 'My last vacation');
      expect(prompt, contains('## Topic'));
      expect(prompt, contains('My last vacation'));
    });

    test('omits topic block when scenario is provided (scenario wins)', () {
      final scenario = Scenario(
        name: 'Job Interview',
        description: '',
        icon: '',
        difficulty: 'intermediate',
        category: 'business',
        systemPrompt: 'You are the hiring manager.',
      );
      final prompt = TutorPromptBuilder.build(
        scenario: scenario,
        sessionTopic: 'should not appear',
      );
      expect(prompt, contains('## Scenario'));
      expect(prompt, isNot(contains('## Topic')));
      expect(prompt, isNot(contains('should not appear')));
    });

    test('omits review block when not a review session even if corrections given', () {
      final corrections = [
        Correction(
          original: 'I goes',
          corrected: 'I go',
          type: CorrectionType.grammar,
        ),
      ];
      final prompt = TutorPromptBuilder.build(
        isReviewSession: false,
        dueCorrections: corrections,
      );
      expect(prompt, isNot(contains('## Review focus')));
    });

    test('omits review block when review session but no corrections', () {
      final prompt = TutorPromptBuilder.build(isReviewSession: true);
      expect(prompt, isNot(contains('## Review focus')));
    });

    test('includes review block when review session AND corrections are present', () {
      final corrections = [
        Correction(
          original: 'I goes',
          corrected: 'I go',
          type: CorrectionType.grammar,
          explanation: 'Subject-verb agreement.',
        ),
        Correction(
          original: 'advices',
          corrected: 'advice',
          type: CorrectionType.vocabulary,
        ),
      ];
      final prompt = TutorPromptBuilder.build(
        isReviewSession: true,
        dueCorrections: corrections,
      );
      expect(prompt, contains('## Review focus'));
      expect(prompt, contains('I goes'));
      expect(prompt, contains('I go'));
      expect(prompt, contains('advices'));
      expect(prompt, contains('advice'));
      // The instructions should explicitly tell the tutor NOT to quiz.
      expect(prompt.toLowerCase(), contains('do not'));
    });

    test('adapts language guidance by user level (beginner)', () {
      final beginner = TutorPromptBuilder.build(userLevel: 'beginner');
      // Beginner spine should mention simple words / chunks.
      expect(beginner.toLowerCase(), anyOf(
        contains('simple'),
        contains('chunk'),
        contains('short'),
      ));
    });

    test('adapts language guidance by user level (advanced)', () {
      final advanced = TutorPromptBuilder.build(userLevel: 'advanced');
      // Advanced spine should mention nuance / register / conditionals.
      expect(advanced.toLowerCase(), anyOf(
        contains('nuance'),
        contains('register'),
        contains('conditional'),
        contains('idiom'),
      ));
    });

    test('composes all sections together in order', () {
      final tutor = TutorRepository.tutors.first;
      final scenario = Scenario(
        name: 'At the airport',
        description: '',
        icon: '✈️',
        difficulty: 'intermediate',
        category: 'travel',
        systemPrompt: 'You are the check-in agent.',
      );
      final corrections = [
        Correction(
          original: 'luggages',
          corrected: 'luggage',
          type: CorrectionType.vocabulary,
        ),
      ];
      final prompt = TutorPromptBuilder.build(
        tutor: tutor,
        scenario: scenario,
        userLevel: 'intermediate',
        isReviewSession: true,
        dueCorrections: corrections,
      );

      // Order: spine → persona → scenario → review focus.
      final personaIdx = prompt.indexOf('## Your persona');
      final scenarioIdx = prompt.indexOf('## Scenario');
      final reviewIdx = prompt.indexOf('## Review focus');
      expect(personaIdx, greaterThan(0));
      expect(scenarioIdx, greaterThan(personaIdx));
      expect(reviewIdx, greaterThan(scenarioIdx));
    });
  });
}
