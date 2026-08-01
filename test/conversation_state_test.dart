import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/chat/domain/conversation_state.dart';

void main() {
  test('beginTurn returns a token and records the initial state', () {
    final machine = ConversationStateMachine();

    final token = machine.beginTurn(ConversationState.generating);

    expect(machine.state, ConversationState.generating);
    expect(machine.isCurrent(token), isTrue);
  });

  test('interrupt invalidates the current turn', () {
    final machine = ConversationStateMachine();
    final token = machine.beginTurn(ConversationState.speaking);

    machine.interrupt();

    expect(machine.state, ConversationState.interrupted);
    expect(machine.isCurrent(token), isFalse);
  });

  test('a newer turn makes an older async result stale', () {
    final machine = ConversationStateMachine();
    final first = machine.beginTurn(ConversationState.generating);
    final second = machine.beginTurn(ConversationState.recording);

    expect(machine.isCurrent(first), isFalse);
    expect(machine.isCurrent(second), isTrue);
    expect(machine.state, ConversationState.recording);
  });
}
