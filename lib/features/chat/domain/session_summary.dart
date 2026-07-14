/// Phase-1 P0 #5 — post-class summary.
///
/// The structured takeaway the LLM produces at the end of a conversation:
/// what the student did well (highlights), exactly three concrete things to
/// improve, and one ready-to-use sentence they can try next time. Kept as a
/// plain immutable model so it serialises cleanly and the summary screen
/// can render it without reaching back into the LLM layer.
class SessionSummary {
  /// What the student did well this session. One or two short lines.
  final String highlights;

  /// Exactly three concrete improvement points, in priority order.
  final List<String> improvements;

  /// One ready-to-use sentence the student can try in their next session.
  final String nextSentence;

  /// The session this summary was generated for (for display / linking).
  final String sessionId;

  const SessionSummary({
    required this.highlights,
    required this.improvements,
    required this.nextSentence,
    required this.sessionId,
  });

  /// True when the LLM returned nothing usable (empty highlights + no
  /// improvements). Lets the screen show a friendly fallback instead of a
  /// blank card.
  bool get isEmpty =>
      highlights.trim().isEmpty && improvements.every((i) => i.trim().isEmpty);
}
