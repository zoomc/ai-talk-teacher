import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/features/chat/domain/conversation_state.dart';

void main() {
  test('beginTurn returns a token and records the initial state', () {
    final machine = ConversationStateMachine();

    final token = machine.beginTurn(ConversationState.generating);

    expect(machine.state, ConversationState.generating);
    expect(machine.isCurrent(token), isTrue);
    expect(machine.isBusy, isTrue);
  });

  test('interrupt invalidates the current turn', () {
    final machine = ConversationStateMachine();
    final token = machine.beginTurn(ConversationState.speaking);

    machine.interrupt();

    expect(machine.state, ConversationState.interrupted);
    expect(machine.isBusy, isFalse);
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

  test('completion is terminal for the current turn but allows a new turn', () {
    final machine = ConversationStateMachine();
    final first = machine.beginTurn(ConversationState.speaking);

    machine.complete();

    expect(machine.state, ConversationState.completed);
    expect(machine.isBusy, isFalse);
    expect(machine.isCurrent(first), isTrue);

    final second = machine.beginTurn(ConversationState.recording);
    expect(machine.isCurrent(first), isFalse);
    expect(machine.isCurrent(second), isTrue);
    expect(machine.isBusy, isTrue);
  });

  test('permission and recoverable error states are not treated as busy', () {
    final machine = ConversationStateMachine();

    machine.beginTurn(ConversationState.permissionRequired);
    expect(machine.isBusy, isFalse);

    machine.transition(ConversationState.recoverableError);
    expect(machine.isBusy, isFalse);
  });
}
