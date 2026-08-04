import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/avatar/presentation/widgets/avatar_stage.dart';
import 'package:speakflow/features/avatar/presentation/widgets/layered_tutor_avatar.dart';

void main() {
  testWidgets('AvatarStage uses the layered 2D renderer by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 380,
          child: AvatarStage(phase: AvatarPhase.idle, tutorName: 'Maya'),
        ),
      ),
    );
    expect(find.byType(LayeredTutorAvatar), findsOneWidget);
    expect(find.text('Maya · Ready'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 80));
  });
}
