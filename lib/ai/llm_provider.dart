/// One turn of a chat completion request.
class LlmMessage {
  const LlmMessage._(this.role, this.content);

  /// Instructions the model should follow for the whole request.
  const LlmMessage.system(String content) : this._('system', content);

  /// The material to work on.
  const LlmMessage.user(String content) : this._('user', content);

  /// A previous answer, when a call needs its own history.
  const LlmMessage.assistant(String content) : this._('assistant', content);

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Base class for chat-completion failures. Mirrors the STT split, and for the
/// same reason: the caller's only real decision is whether trying again could
/// help.
abstract class AiException implements Exception {
  const AiException(
    this.message, {
    this.statusCode,
    this.kind,
    this.reason,
    this.retryAfter,
    this.source,
  });

  final String message;
  final int? statusCode;

  /// Provider-specific failure kind (Gemini sets a `GeminiErrorKind`).
  final Enum? kind;

  /// The provider's own short explanation, safe to show.
  final String? reason;

  /// How long the provider asked to wait (`retry-after`), when it said.
  final Duration? retryAfter;

  /// The service that failed, by its label, when the router knows.
  final String? source;

  @override
  String toString() =>
      '$runtimeType($message${statusCode == null ? '' : ', HTTP $statusCode'})';
}

/// Rate limits, server errors, timeouts, no connectivity.
class AiTransientException extends AiException {
  const AiTransientException(super.message,
      {super.statusCode,
      super.kind,
      super.reason,
      super.retryAfter,
      super.source});
}

/// Bad or missing API key, a retired model id, a malformed request.
class AiPermanentException extends AiException {
  const AiPermanentException(super.message,
      {super.statusCode, super.kind, super.reason, super.source});
}

/// One completed reply, with whatever the backend did on its own to produce
/// it.
class LlmCompletion {
  const LlmCompletion({required this.content, this.executedTools = const []});

  final String content;

  /// Tools the backend ran server-side, verbatim as it reported them.
  ///
  /// Groq's agentic models put their web searches here, results and URLs
  /// included, which is the difference between a source the model *used* and a
  /// source it *says* it used. Left as raw JSON because the shape is the
  /// provider's, not this interface's — the one caller that reads it treats it
  /// as untrusted data and validates every link it finds.
  final List<Object?> executedTools;
}

/// A chat-completion backend. Groq is the only implementation; the interface
/// exists for the same reason [SttProvider] does — so a second one is a pure
/// addition rather than a refactor.
abstract class LlmProvider {
  /// Returns the assistant's reply as plain text.
  ///
  /// [jsonMode] asks the backend to constrain the reply to a single JSON
  /// object. It makes malformed JSON unlikely, never impossible, so callers
  /// still parse defensively.
  Future<String> complete({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) async =>
      (await completeDetailed(
        model: model,
        messages: messages,
        temperature: temperature,
        maxTokens: maxTokens,
        jsonMode: jsonMode,
        timeout: timeout,
      ))
          .content;

  /// The same call, keeping what [complete] throws away. Only the web-answer
  /// path needs it.
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  });
}
