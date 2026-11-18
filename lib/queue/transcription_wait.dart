import '../core/formatting.dart';

/// Why transcription is standing still, when it is not simply working.
enum TranscriptionWaitKind {
  /// A service asked for a pause; the queue resumes by itself at [TranscriptionWait.until].
  rateLimit,

  /// No transcription engine has a key; saving one lifts it.
  missingKey,
}

class TranscriptionWait {
  const TranscriptionWait.rateLimit(DateTime this.until)
    : kind = TranscriptionWaitKind.rateLimit;

  const TranscriptionWait.missingKey()
    : kind = TranscriptionWaitKind.missingKey,
      until = null;

  final TranscriptionWaitKind kind;
  final DateTime? until;

  @override
  bool operator ==(Object other) =>
      other is TranscriptionWait && other.kind == kind && other.until == until;

  @override
  int get hashCode => Object.hash(kind, until);
}

/// The notice for chunks that are saved but not yet transcribed, counted in
/// correct Czech („1 úseku", „3 úseků").
String pendingChunksText(int pending) =>
    'Zvuk je uložený. Přepis čeká na zpracování $pending '
    '${pending == 1 ? 'úseku' : 'úseků'}; po připojení doběhne automaticky.';

/// What the student reads while chunks wait: one sentence that says why, and
/// for a limit also when it ends.
String transcriptionWaitText(TranscriptionWait wait) {
  switch (wait.kind) {
    case TranscriptionWaitKind.missingKey:
      return 'Chybí klíč pro přepis — ulož ho v Nastavení';
    case TranscriptionWaitKind.rateLimit:
      final until = wait.until;
      return until == null
          ? 'Přepis čeká na limit služby'
          : 'Přepis čeká na limit, pokračuje v ${formatTimeOfDay(until)}';
  }
}
