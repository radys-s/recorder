import '../core/constants.dart';
import '../core/logging.dart';
import 'gemini_provider.dart' show LlmImage;
import 'llm_provider.dart';
import 'openai_compatible_provider.dart';

/// The services the router can send text to, in no particular order.
enum AiVendor { custom, cerebras, mistral, groq }

extension AiVendorLabel on AiVendor {
  String get label => switch (this) {
    AiVendor.custom => 'Vlastní',
    AiVendor.cerebras => 'Cerebras',
    AiVendor.mistral => 'Mistral',
    AiVendor.groq => 'Groq',
  };
}

/// What a request needs: many small calls, a smart answer, or a picture.
enum AiTier { fast, strong, vision }

/// One service the router may use: its provider and the models to try for
/// each tier, in order. An empty list means the tier is not offered.
class AiRoute {
  AiRoute({
    required this.vendor,
    required this.provider,
    required this.models,
    this.maxInputTokens,
  });

  final AiVendor vendor;
  final OpenAiCompatibleProvider provider;

  /// [requested] is the model the calling service asked for (a Groq id).
  final Future<List<String>> Function(AiTier tier, String requested) models;

  /// Requests estimated above this skip the route.
  final int? maxInputTokens;
}

/// Cooldowns and disabled services, shared by every router instance so the
/// corrector and the answer services see the same picture.
class AiRouteHealth {
  AiRouteHealth({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<AiVendor, DateTime> _until = {};
  final Map<AiVendor, Duration> _last = {};

  /// Vendors whose key was refused, with the key that was refused — a new key
  /// typed in Settings lifts it.
  final Map<AiVendor, int> _disabledKey = {};
  final Map<AiVendor, String> _lastModel = {};

  DateTime get now => _now();

  bool coolingDown(AiVendor v) {
    final until = _until[v];
    return until != null && until.isAfter(_now());
  }

  DateTime? cooldownUntil(AiVendor v) => coolingDown(v) ? _until[v] : null;

  void cool(AiVendor v, Duration? retryAfter) {
    final previous = _last[v];
    var wait = retryAfter ?? (previous == null ? kRouteCooldown : previous * 2);
    if (wait > kRouteMaxCooldown) wait = kRouteMaxCooldown;
    if (wait < const Duration(seconds: 1)) wait = const Duration(seconds: 1);
    _last[v] = wait;
    _until[v] = _now().add(wait);
  }

  void succeeded(AiVendor v, String model) {
    _last.remove(v);
    _until.remove(v);
    _lastModel[v] = model;
  }

  void disable(AiVendor v, String key) => _disabledKey[v] = key.hashCode;

  bool disabled(AiVendor v, String key) => _disabledKey[v] == key.hashCode;

  bool anyDisabled(AiVendor v) => _disabledKey.containsKey(v);

  String? lastModel(AiVendor v) => _lastModel[v];
}

/// An [LlmProvider] that spreads requests over every service with a key.
///
/// Services call it exactly like the Groq provider they used before, so none
/// of them changed. A rate limit or an overload moves the request to the next
/// service at once and rests the busy one; a refused key rests it until the
/// key changes. Nothing is configurable — the order is a fixed rule per tier.
class RoutedLlmProvider extends LlmProvider {
  RoutedLlmProvider({required this.routes, required this.health});

  static const _tag = 'ai.router';

  final List<AiRoute> routes;
  final AiRouteHealth health;

  AiRoute? _route(AiVendor v) {
    for (final r in routes) {
      if (r.vendor == v) return r;
    }
    return null;
  }

  /// The order for one request.
  static List<AiVendor> orderFor(String model, int inputTokens, AiTier tier) {
    if (model.startsWith('groq/')) return const [AiVendor.groq];
    return switch (tier) {
      AiTier.vision => const [AiVendor.custom, AiVendor.mistral],
      AiTier.fast => const [
        AiVendor.custom,
        AiVendor.cerebras,
        AiVendor.groq,
        AiVendor.mistral,
      ],
      AiTier.strong when inputTokens > kRouterLargeInputTokens => const [
        AiVendor.custom,
        AiVendor.mistral,
        AiVendor.cerebras,
        AiVendor.groq,
      ],
      AiTier.strong => const [
        AiVendor.custom,
        AiVendor.cerebras,
        AiVendor.mistral,
        AiVendor.groq,
      ],
    };
  }

  static AiTier tierFor(String model) =>
      model == kGroqCorrectionModel ? AiTier.fast : AiTier.strong;

  static int estimateTokens(List<LlmMessage> messages) =>
      (messages.fold<int>(0, (n, m) => n + m.content.length) / 3).ceil();

  /// True when some service with a key can read pictures.
  Future<bool> hasVisionRoute() async {
    for (final v in orderFor('', 0, AiTier.vision)) {
      final route = _route(v);
      if (route == null || await route.provider.keyStore.read() == null) {
        continue;
      }
      if ((await route.models(AiTier.vision, '')).isNotEmpty) return true;
    }
    return false;
  }

  @override
  Future<LlmCompletion> completeDetailed({
    required String model,
    required List<LlmMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) => _run(
    requested: model,
    tier: tierFor(model),
    messages: messages,
    temperature: temperature,
    maxTokens: maxTokens,
    jsonMode: jsonMode,
    timeout: timeout,
  );

  /// A picture request; only services that read pictures are tried.
  Future<LlmCompletion> completeVision({
    required List<LlmMessage> messages,
    required List<LlmImage> images,
    int? maxTokens,
    bool jsonMode = false,
    Duration? timeout,
  }) => _run(
    requested: '',
    tier: AiTier.vision,
    messages: messages,
    images: images,
    temperature: 0.1,
    maxTokens: maxTokens,
    jsonMode: jsonMode,
    timeout: timeout,
  );

  Future<LlmCompletion> _run({
    required String requested,
    required AiTier tier,
    required List<LlmMessage> messages,
    List<LlmImage> images = const [],
    required double temperature,
    int? maxTokens,
    required bool jsonMode,
    Duration? timeout,
  }) async {
    final tokens = estimateTokens(messages);
    final order = orderFor(requested, tokens, tier);

    // Services with a usable key, split into rested and cooling. Cooling ones
    // are still tried last: an app that refuses to answer for ten minutes
    // after one 429 is worse than a request that might fail again.
    final ready = <(AiRoute, String, List<String>)>[];
    final cooling = <(AiRoute, String, List<String>)>[];
    for (final v in order) {
      final route = _route(v);
      if (route == null) continue;
      final max = route.maxInputTokens;
      if (max != null && tokens > max) continue;
      final key = await route.provider.keyStore.read();
      if (key == null || health.disabled(v, key)) continue;
      final models = await route.models(tier, requested);
      if (models.isEmpty) continue;
      (health.coolingDown(v) ? cooling : ready).add((route, key, models));
    }
    final candidates = [...ready, ...cooling];

    if (candidates.isEmpty) {
      if (tier == AiTier.vision) {
        throw const AiPermanentException(
          'Fotky umí přečíst Gemini nebo Mistral. Přidej klíč v Nastavení.',
        );
      }
      // Keeps the message the app has always shown without a Groq key.
      throw const AiPermanentException(
        'No Groq API key configured. Add one in Settings.',
      );
    }

    AiException? transient;
    AiException? permanent;
    for (final (route, key, models) in candidates) {
      for (final id in models) {
        try {
          final result = await route.provider.completeWithImages(
            model: id,
            messages: messages,
            images: images,
            temperature: temperature,
            maxTokens: maxTokens,
            jsonMode: jsonMode,
            timeout: timeout,
          );
          health.succeeded(route.vendor, id);
          if (route.vendor != AiVendor.groq || id != requested) {
            AppLog.d(_tag, '${tier.name} answered by ${route.vendor.name}/$id');
          }
          return result;
        } on AiTransientException catch (e) {
          transient = e;
          // A status means the service itself pushed back; no status is the
          // phone's network, which the next service would hit just the same.
          if (e.statusCode != null) health.cool(route.vendor, e.retryAfter);
          AppLog.d(_tag, '${route.vendor.name}/$id transient: ${e.message}');
          break;
        } on AiPermanentException catch (e) {
          permanent = e;
          AppLog.d(_tag, '${route.vendor.name}/$id permanent: ${e.message}');
          if (e.statusCode == 404) continue; // try the vendor's next model
          if (e.statusCode == 401 || e.statusCode == 403) {
            health.disable(route.vendor, key);
          }
          break;
        }
      }
      // A network failure with no status will not go better elsewhere.
      if (transient != null && transient.statusCode == null) break;
    }
    throw transient ?? permanent!;
  }
}
