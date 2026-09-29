/// The address of the user's own OpenAI-compatible service ("Vlastní").
///
/// The stored key is sent to whatever this points at, so it is held to the
/// strictest reading of "a school model": https only (a key over plain http
/// crosses the network in the clear), no `user:password@` part (it would be
/// logged and shown), no query or fragment (a token in a URL ends up in
/// proxies' logs). Everything else about the URL is the user's business.
class CustomEndpoint {
  const CustomEndpoint._({this.url, this.problem});

  /// The normalised address (no trailing slash), or null when [problem] is set.
  final String? url;

  /// A Czech sentence saying what is wrong, or null when the address is fine.
  final String? problem;

  bool get valid => url != null;

  /// Lower-cased host, for comparing "the same service" before and after an
  /// edit.
  String? get host => url == null ? null : Uri.parse(url!).host.toLowerCase();
}

CustomEndpoint checkCustomEndpoint(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) {
    return const CustomEndpoint._(problem: 'Vyplň adresu služby.');
  }
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return const CustomEndpoint._(
      problem: 'Adresa nevypadá správně. Příklad: https://ai.skola.cz/v1',
    );
  }
  if (uri.scheme.toLowerCase() != 'https') {
    return const CustomEndpoint._(
      problem:
          'Adresa musí začínat https://. Klíč by se jinak posílal '
          'nezašifrovaně.',
    );
  }
  if (uri.userInfo.isNotEmpty) {
    return const CustomEndpoint._(
      problem: 'Adresa nesmí obsahovat jméno nebo heslo (část před @).',
    );
  }
  if (uri.hasQuery || uri.hasFragment) {
    return const CustomEndpoint._(
      problem: 'Adresa nesmí obsahovat parametry (?…) ani odkaz (#…).',
    );
  }
  var url = uri.toString();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return CustomEndpoint._(url: url);
}
