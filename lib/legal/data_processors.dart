/// A service outside the app that the student's data can go to, with what
/// goes there and where its own rules are. Shown in Settings next to each key.
enum DataProcessor {
  groq(
    name: 'Groq',
    sent:
        'Úseky zvuku k přepisu a text přepisu, otázek a poznámek '
        'k odpovědím a výpiskům.',
    training: null,
    termsUrl: 'https://groq.com/terms-of-use',
    privacyUrl: 'https://groq.com/privacy-policy',
  ),
  gemini(
    name: 'Google Gemini',
    sent:
        'Fotky, text přepisu a otázek, dotazy k dohledání na webu a po '
        'hodině celá nahrávka pro vylepšený přepis.',
    training:
        'V bezplatném tarifu může Google vstupy použít ke zlepšování '
        'svých produktů a mohou je číst lidští hodnotitelé.',
    termsUrl: 'https://ai.google.dev/gemini-api/terms',
    privacyUrl: 'https://policies.google.com/privacy',
  ),
  mistral(
    name: 'Mistral',
    sent: 'Text přepisu, otázek a poznámek; fotky, když Gemini nejde.',
    training:
        'Bezplatný tarif Experiment může vstupy použít k tréninku. '
        'Vypnout to jde v nastavení účtu Mistral (Privacy).',
    termsUrl: 'https://legal.mistral.ai/terms',
    privacyUrl: 'https://legal.mistral.ai/terms/privacy-policy',
  ),
  cerebras(
    name: 'Cerebras',
    sent: 'Text přepisu, otázek a poznámek. Nikdy zvuk ani fotky.',
    training: null,
    termsUrl: null,
    privacyUrl: 'https://www.cerebras.ai/privacy-policy',
  ),
  custom(
    name: 'Vlastní služba',
    sent: 'Text přepisu, otázek a poznámek na adresu, kterou zadáš.',
    training:
        'Co služba s daty dělá, řídí její provozovatel — zjisti si to '
        'u něj.',
    termsUrl: null,
    privacyUrl: null,
  ),
  googleDrive(
    name: 'Google Disk',
    sent:
        'Výpisky a volitelně přepisy tvých předmětů, jen do souborů, které '
        'aplikace sama vytvoří.',
    training: null,
    termsUrl: 'https://policies.google.com/terms',
    privacyUrl: 'https://policies.google.com/privacy',
  );

  const DataProcessor({
    required this.name,
    required this.sent,
    required this.training,
    required this.termsUrl,
    required this.privacyUrl,
  });

  final String name;

  /// What leaves the phone for this service.
  final String sent;

  /// A warning about use for training, or null when there is none to give.
  final String? training;

  final String? termsUrl;
  final String? privacyUrl;
}
