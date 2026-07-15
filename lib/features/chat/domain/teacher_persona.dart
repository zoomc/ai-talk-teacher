import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// S7/S8 — a teacher persona matrix entry.
///
/// Each persona is a named "AI tutor style" the user can switch between.
/// The three canonical styles ship with the app:
///   'strict'    — demanding, error-focused, brief praise.
///   'encourage' — warm, positive, celebrates small wins.
///   'humor'     — playful, light, uses jokes to lower affective filter.
///
/// `temp` is the LLM sampling temperature (0.0–1.0+) the chat service
/// blends with the active LLM profile's own temperature when this persona
/// is active. Lower → more deterministic (good for 'strict'); higher →
/// more varied (good for 'humor'). Stored as a REAL in SQLite.
///
/// `promptTemplate` is the system-prompt skeleton inserted before the
/// scenario's own system_prompt. The placeholder `{scenario_prompt}` is
/// replaced at chat-session build time so the persona wraps the scenario
/// instead of overriding it.
class TeacherPersona {
  final String id;
  final String name;
  final String style;
  final double temp;
  final String promptTemplate;

  TeacherPersona({
    String? id,
    required this.name,
    required this.style,
    required this.temp,
    required this.promptTemplate,
  }) : id = id ?? _uuid.v4();

  TeacherPersona copyWith({
    String? name,
    String? style,
    double? temp,
    String? promptTemplate,
  }) {
    return TeacherPersona(
      id: id,
      name: name ?? this.name,
      style: style ?? this.style,
      temp: temp ?? this.temp,
      promptTemplate: promptTemplate ?? this.promptTemplate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'style': style,
      'temp': temp,
      'prompt_template': promptTemplate,
    };
  }

  factory TeacherPersona.fromMap(Map<String, dynamic> map) {
    return TeacherPersona(
      id: map['id'] as String,
      name: map['name'] as String,
      style: map['style'] as String,
      temp: (map['temp'] as num?)?.toDouble() ?? 0.7,
      promptTemplate: map['prompt_template'] as String,
    );
  }

  /// Render the persona's system prompt for the given scenario prompt.
  /// When [scenarioPrompt] is null/empty, the persona runs on its own
  /// (free-talk mode).
  String renderSystemPrompt(String? scenarioPrompt) {
    final sp = (scenarioPrompt == null || scenarioPrompt.isEmpty)
        ? ''
        : scenarioPrompt;
    return promptTemplate.replaceAll('{scenario_prompt}', sp);
  }
}

/// S7/S8 — the three canonical teacher persona styles. Kept as a const
/// list so the settings picker and the seed migration share a single
/// source of truth.
class TeacherPersonaStyle {
  static const String strict = 'strict';
  static const String encourage = 'encourage';
  static const String humor = 'humor';

  static const List<String> all = [strict, encourage, humor];

  /// Validate a stored style string. Returns the input if it's one of
  /// the known values, otherwise [encourage] (the safe default).
  static String normalize(String? raw) {
    if (raw == null) return encourage;
    return all.contains(raw) ? raw : encourage;
  }

  /// i18n key for the human-readable name of [style].
  static String labelKey(String style) {
    switch (style) {
      case strict:
        return 'persona.style_strict';
      case encourage:
        return 'persona.style_encourage';
      case humor:
        return 'persona.style_humor';
      default:
        return 'persona.style_encourage';
    }
  }

  /// i18n key for the description of [style].
  static String descKey(String style) {
    switch (style) {
      case strict:
        return 'persona.style_strict_desc';
      case encourage:
        return 'persona.style_encourage_desc';
      case humor:
        return 'persona.style_humor_desc';
      default:
        return 'persona.style_encourage_desc';
    }
  }
}
