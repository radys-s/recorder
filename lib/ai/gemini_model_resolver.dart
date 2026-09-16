import '../core/constants.dart';
import '../core/logging.dart';

/// The two Gemini models the app talks to, as ids this key really offers.
class GeminiModelPair {
  const GeminiModelPair({required this.main, required this.lite});

  final String main;
  final String lite;
}

/// Picks the models to use from the ids Google lists for the key.
///
/// The app names its models by the constants [kGeminiModel] and
/// [kGeminiLiteModel]; those are preferred whenever they are listed. When
/// Google has renamed or withdrawn one, the newest general-purpose Flash (or
/// Flash-Lite) takes its place, stable releases before previews. Returns null
/// when the list holds no Flash model at all.
GeminiModelPair? pickGeminiModels(List<String> ids, {String? override}) {
  final available = ids.toSet();

  final main = (override != null && available.contains(override))
      ? override
      : available.contains(kGeminiModel)
          ? kGeminiModel
          : _newest(ids.where((id) => _isFlash(id) && !_isLite(id)));
  if (main == null) return null;

  final lite = available.contains(kGeminiLiteModel)
      ? kGeminiLiteModel
      : _newest(ids.where(_isLite)) ?? main;
  return GeminiModelPair(main: main, lite: lite);
}

/// General-purpose Flash models the user may pick in Settings.
List<String> selectableGeminiModels(List<String> ids) {
  final list = ids.where(_isFlash).toList();
  list.sort((a, b) => _compare(b, a));
  return list;
}

const _specialised = [
  'image',
  'tts',
  'live',
  'audio',
  'embedding',
  'robotics',
  'computer-use',
  'native',
  'exp',
  'thinking',
  'learnlm',
];

bool _isFlash(String id) {
  if (!id.startsWith('gemini-') || !id.contains('-flash')) return false;
  return !_specialised.any(id.contains);
}

bool _isLite(String id) => _isFlash(id) && id.contains('-flash-lite');

bool _isPreview(String id) => id.contains('preview');

/// Version number in `gemini-<version>-flash…`, e.g. 3.5 → [3, 5].
List<int> _version(String id) {
  final match = RegExp(r'^gemini-(\d+)(?:\.(\d+))?').firstMatch(id);
  if (match == null) return const [0, 0];
  return [int.parse(match.group(1)!), int.parse(match.group(2) ?? '0')];
}

/// Higher version first; within one version stable before preview, and a
/// plain alias (`gemini-3-flash`) before a dated one.
int _compare(String a, String b) {
  final va = _version(a), vb = _version(b);
  if (va[0] != vb[0]) return va[0].compareTo(vb[0]);
  if (va[1] != vb[1]) return va[1].compareTo(vb[1]);
  if (_isPreview(a) != _isPreview(b)) return _isPreview(a) ? -1 : 1;
  return b.length.compareTo(a.length);
}

String? _newest(Iterable<String> ids) {
  String? best;
  for (final id in ids) {
    if (best == null || _compare(id, best) > 0) best = id;
  }
  return best;
}

/// Turns the app's model names into ids the key can use.
///
/// The fast path costs nothing: the configured id is used as is. Only when
/// Google answers 404 does [reresolve] ask for the model list, and the result
/// is remembered for the rest of the process. A model chosen in Settings wins
/// over the constants from the first call on.
class GeminiModelResolver {
  GeminiModelResolver({required this._listModels, this._override});

  static const _tag = 'ai.gemini.models';

  final Future<List<String>> Function() _listModels;
  final Future<String?> Function()? _override;
  GeminiModelPair? _resolved;

  /// The id to send for [requested].
  Future<String> resolve(String requested) async {
    final pair = _resolved;
    if (pair != null) return _map(pair, requested);

    if (requested == kGeminiModel) {
      final chosen = await _safeOverride();
      if (chosen != null) return chosen;
    }
    return requested;
  }

  /// After a 404 on [failedId]: asks Google, and returns a different id to try
  /// for [requested], or null when there is nothing better.
  Future<String?> reresolve(String requested, String failedId) async {
    try {
      final ids = await _listModels();
      final pair = pickGeminiModels(ids, override: await _safeOverride());
      if (pair == null) {
        AppLog.d(_tag, 'no Flash model offered to this key');
        return null;
      }
      _resolved = pair;
      final next = _map(pair, requested);
      AppLog.d(_tag, '$failedId missing; using $next');
      return next == failedId ? null : next;
    } catch (e) {
      AppLog.d(_tag, 'model list failed: $e');
      return null;
    }
  }

  /// Use [pair] from now on, e.g. after „Ověřit klíč" listed the models.
  void use(GeminiModelPair pair) => _resolved = pair;

  /// Forget what was resolved, e.g. after a different model was picked.
  void reset() => _resolved = null;

  String _map(GeminiModelPair pair, String requested) =>
      requested == kGeminiModel
          ? pair.main
          : requested == kGeminiLiteModel
              ? pair.lite
              : requested;

  Future<String?> _safeOverride() async {
    try {
      final value = (await _override?.call())?.trim();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }
}
