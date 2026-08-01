/// The single semantic state vocabulary shared by recording, generation,
/// playback and the avatar surface.
enum ConversationState {
  idle,
  permissionRequired,
  recording,
  transcribing,
  generating,
  synthesizing,
  speaking,
  interrupted,
  completed,
  recoverableError,
  fatalError,
}

/// Small, UI-agnostic state machine used to guard asynchronous turns.
///
/// Every new turn receives a monotonically increasing token. Async work must
/// check [isCurrent] before committing a result; this prevents a late STT/LLM
/// callback from overwriting a newer conversation state.
class ConversationStateMachine {
  ConversationState _state = ConversationState.idle;
  int _turn = 0;

  ConversationState get state => _state;
  int get turn => _turn;

  /// Starts a new logical turn and returns its cancellation token.
  int beginTurn(ConversationState initial) {
    _turn++;
    _state = initial;
    return _turn;
  }

  /// Changes state without creating a new turn.
  void transition(ConversationState next) {
    _state = next;
  }

  bool isCurrent(int token) => token == _turn;

  /// Invalidates all outstanding async work and moves through an explicit
  /// interrupted state before the next frame returns the UI to idle.
  void interrupt() {
    _turn++;
    _state = ConversationState.interrupted;
  }

  void complete() => _state = ConversationState.completed;

  void recover() => _state = ConversationState.idle;
}
