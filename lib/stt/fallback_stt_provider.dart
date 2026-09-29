import 'dart:io';

import '../core/logging.dart';
import '../data/db/tables/preferences_table.dart';
import 'stt_provider.dart';

/// One way of transcribing a chunk, and whether it can be used right now.
class SttEngine {
  const SttEngine(this.id, this.provider, this.hasKey);

  /// Stable label, also what is stored beside a segment.
  final String id;
  final SttProvider provider;

  /// False when the key this engine needs is not set, so it is skipped
  /// without spending a request.
  final Future<bool> Function() hasKey;
}

/// Tries the engines in order and rests the one that is rate limited.
///
/// Each engine has its own limit, so Groq's large model running dry moves the
/// chunk to the turbo model and then to Gemini instead of stopping the
/// transcript. A cooldown is per engine and doubles while it keeps failing;
/// a success clears it. The order is fixed — nothing here is configurable.
class FallbackSttProvider implements SttProvider {
  FallbackSttProvider(
    this.engines, {
    DateTime Function()? now,
    this.baseCooldown = const Duration(seconds: 60),
    this.maxCooldown = const Duration(minutes: 10),
  }) : _now = now ?? DateTime.now;

  static const _tag = 'stt.fallback';

  final List<SttEngine> engines;
  final DateTime Function() _now;
  final Duration baseCooldown;
  final Duration maxCooldown;

  final Map<String, DateTime> _until = {};
  final Map<String, Duration> _last = {};

  bool coolingDown(String id) {
    final until = _until[id];
    return until != null && until.isAfter(_now());
  }

  DateTime? cooldownUntil(String id) => coolingDown(id) ? _until[id] : null;

  void _cool(String id, Duration? retryAfter) {
    final previous = _last[id];
    var wait = retryAfter ?? (previous == null ? baseCooldown : previous * 2);
    if (wait > maxCooldown) wait = maxCooldown;
    if (wait < const Duration(seconds: 1)) wait = const Duration(seconds: 1);
    _last[id] = wait;
    _until[id] = _now().add(wait);
  }

  void _succeeded(String id) {
    _last.remove(id);
    _until.remove(id);
  }

  @override
  Future<TranscriptionResult> transcribe({
    required File audioFile,
    String? promptContext,
    String? languageCode,
    MicSensitivity sensitivity = MicSensitivity.medium,
    String? glossary,
    double? noSpeechProbThreshold,
    double? lowAvgLogprobThreshold,
    Duration? timeout,
  }) async {
    var tried = false;
    SttPermanentException? refused;
    SttException? failed;
    Duration? soonest;

    void rest(String id) {
      final left = _until[id]!.difference(_now());
      if (soonest == null || left < soonest!) soonest = left;
    }

    for (final engine in engines) {
      if (coolingDown(engine.id)) {
        rest(engine.id);
        continue;
      }
      if (!await engine.hasKey()) continue;
      try {
        final result = await engine.provider.transcribe(
          audioFile: audioFile,
          promptContext: promptContext,
          languageCode: languageCode,
          sensitivity: sensitivity,
          glossary: glossary,
          noSpeechProbThreshold: noSpeechProbThreshold,
          lowAvgLogprobThreshold: lowAvgLogprobThreshold,
          timeout: timeout,
        );
        _succeeded(engine.id);
        return result;
      } on SttRateLimited catch (e) {
        tried = true;
        _cool(engine.id, e.retryAfter);
        rest(engine.id);
        AppLog.d(_tag, '${engine.id} rate limited — trying the next engine');
      } on SttKeyMissing {
        // The engine's own check said no; nothing was sent.
      } on SttPermanentException catch (e) {
        tried = true;
        final status = e.statusCode;
        if (status == 401 || status == 403) {
          // This key is refused; another engine may use a different one.
          _cool(engine.id, maxCooldown);
          refused = e;
          continue;
        }
        // The audio itself was rejected; the next engine would say the same.
        rethrow;
      } on SttTransientException catch (e) {
        tried = true;
        final status = e.statusCode;
        if (status != null && status >= 500) _cool(engine.id, null);
        failed = e;
      }
    }

    if (failed != null) throw failed;
    if (soonest != null) {
      throw SttRateLimited(
        'Přepisovací služby jsou přetížené.',
        retryAfter: soonest,
        statusCode: 429,
      );
    }
    if (refused != null) throw refused;
    if (!tried) {
      throw const SttKeyMissing(
        'Chybí klíč pro přepis. Přidej ho v Nastavení.',
      );
    }
    throw const SttTransientException('Přepis se nepodařil.');
  }
}
