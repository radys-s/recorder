import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatting.dart';
import '../../core/logging.dart';
import '../../core/providers.dart';
import '../../core/spacing.dart';
import '../../core/widgets/section_header.dart';
import '../../data/db/app_database.dart';
import '../../data/db/tables/drive_docs_table.dart';
import '../../sync/drive_api.dart';
import '../../sync/drive_sync_service.dart';
import '../../sync/google_auth.dart';
import '../../sync/web_authenticator.dart';
import '../subjects/subjects_providers.dart';

const _tag = 'ui.settings.drive';

/// The bundle id the app really runs with. A sideloaded build can carry a
/// different one than the project, and Google's iOS client must match it.
final appBundleIdProvider = FutureProvider.autoDispose<String?>((ref) {
  return ref.watch(webAuthenticatorProvider).bundleId();
});

/// „NotebookLM (Google Disk)" — mirrors each subject into a Google Doc the
/// student adds to NotebookLM as a source.
class DriveSyncSection extends ConsumerStatefulWidget {
  const DriveSyncSection({super.key});

  @override
  ConsumerState<DriveSyncSection> createState() => _DriveSyncSectionState();
}

class _DriveSyncSectionState extends ConsumerState<DriveSyncSection> {
  final _clientId = TextEditingController();
  bool _editingClientId = false;
  bool _busy = false;

  @override
  void dispose() {
    _clientId.dispose();
    super.dispose();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _busyWhile(Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveClientId(Preference? prefs) async {
    final value = _clientId.text.trim();
    if (!isValidGoogleClientId(value)) {
      _say('Tohle nevypadá jako Client ID — končí na '
          '.apps.googleusercontent.com.');
      return;
    }
    await _busyWhile(() async {
      // A new client belongs to another Cloud project; the old sign-in is
      // no use with it.
      if (prefs?.googleAccountEmail != null) {
        await ref.read(googleAccountProvider).signOut();
      }
      await ref.read(preferencesDaoProvider).setGoogleClientId(value);
    });
    if (!mounted) return;
    setState(() => _editingClientId = false);
    _clientId.clear();
  }

  Future<void> _signIn() => _busyWhile(() async {
    try {
      final warning = await ref.read(googleAccountProvider).signIn();
      _say(warning ?? 'Přihlášeno ke Googlu.');
      final prefs = await ref.read(preferencesDaoProvider).current();
      if (prefs.driveSyncEnabled) {
        unawaited(ref.read(driveSyncServiceProvider).syncAll());
      }
    } on WebAuthCancelled {
      // The student closed the sheet; nothing to say.
    } on GoogleSignInException catch (e) {
      _say(e.message);
    } on DriveException catch (e) {
      _say(e.message);
    } on PlatformException catch (e, st) {
      AppLog.e(_tag, 'sign-in sheet failed', e, st);
      _say('Přihlášení se nepodařilo (${e.message ?? e.code}).');
    } catch (e, st) {
      AppLog.e(_tag, 'sign-in failed', e, st);
      _say('Přihlášení se nepodařilo. Zkus to znovu.');
    }
  });

  Future<void> _syncNow() => _busyWhile(() async {
    final report = await ref.read(driveSyncServiceProvider).syncAll();
    _say(driveSyncMessage(report));
  });

  Future<void> _signOut() => _busyWhile(() async {
    await ref.read(googleAccountProvider).signOut();
    _say('Odhlášeno. Dokumenty na Disku zůstávají.');
  });

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider).valueOrNull;
    final clientId = prefs?.googleClientId?.trim();
    final hasClient = clientId != null && clientId.isNotEmpty;
    final email = prefs?.googleAccountEmail;
    final signedIn = hasClient && email != null;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'NotebookLM (Google Disk)',
          description:
              'Výpisky každého předmětu jako Google dokument na tvém Disku, '
              'který si NotebookLM přidá jako zdroj. Aplikace vidí jen '
              'soubory, které sama vytvořila.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!hasClient || _editingClientId) ...[
                  Text(
                    hasClient
                        ? 'Nové Client ID z Google Cloud:'
                        : 'Jednorázově si v Google Cloud vytvoř přihlašovací '
                              'klient (asi 10 minut) a vlož sem jeho Client ID.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Gap.md),
                  TextField(
                    controller: _clientId,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Client ID',
                      hintText: '123-abc.apps.googleusercontent.com',
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : () => _saveClientId(prefs),
                          icon: const Icon(Icons.save),
                          label: const Text('Uložit'),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showDriveSetupGuide(context),
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('Návod'),
                        ),
                      ),
                    ],
                  ),
                  if (_editingClientId)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _editingClientId = false),
                        child: const Text('Zrušit'),
                      ),
                    ),
                ] else ...[
                  Row(
                    children: [
                      Icon(
                        signedIn
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          !signedIn
                              ? 'Nepřihlášeno'
                              : email.isEmpty
                              ? 'Přihlášeno'
                              : 'Přihlášeno jako $email',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(
                    'Client ID …${_tail(clientId)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  if (!signedIn)
                    FilledButton.icon(
                      onPressed: _busy ? null : _signIn,
                      icon: const Icon(Icons.login),
                      label: const Text('Přihlásit se Googlem'),
                    )
                  else ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Posílat výpisky automaticky'),
                      subtitle: const Text(
                        'Po každé změně, zhruba do půl minuty.',
                      ),
                      value: prefs?.driveSyncEnabled ?? false,
                      onChanged: _busy
                          ? null
                          : (v) => ref
                                .read(preferencesDaoProvider)
                                .setDriveSyncEnabled(v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Přidat i přepisy'),
                      subtitle: const Text(
                        'Druhý dokument na předmět s přepisy hodin. NotebookLM '
                        'pak zná i to, co ve výpiscích není.',
                      ),
                      value: prefs?.driveIncludeTranscripts ?? false,
                      onChanged: _busy
                          ? null
                          : (v) => ref
                                .read(preferencesDaoProvider)
                                .setDriveIncludeTranscripts(v),
                    ),
                    const SizedBox(height: Gap.sm),
                    FilledButton.icon(
                      onPressed: _busy ? null : _syncNow,
                      icon: const Icon(Icons.sync),
                      label: const Text('Synchronizovat teď'),
                    ),
                    const _DocStatusList(),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: Gap.md),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: Gap.sm),
                  Wrap(
                    spacing: Gap.sm,
                    children: [
                      TextButton(
                        onPressed: () => showDriveSetupGuide(context),
                        child: const Text('Návod'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _editingClientId = true),
                        child: const Text('Změnit Client ID'),
                      ),
                      if (signedIn)
                        TextButton(
                          onPressed: _busy ? null : _signOut,
                          child: const Text('Odhlásit'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _tail(String id) {
    final prefix = id.replaceFirst('.apps.googleusercontent.com', '');
    return prefix.length <= 8 ? prefix : prefix.substring(prefix.length - 8);
  }
}

/// A sentence for the student about how a sync went.
String driveSyncMessage(DriveSyncReport report) {
  switch (report.outcome) {
    case DriveSyncOutcome.notSignedIn:
      return 'Nejdřív se přihlas ke Googlu.';
    case DriveSyncOutcome.needsSignIn:
      return report.error ?? 'Přihlášení ke Googlu vypršelo. Přihlas se znovu.';
    case DriveSyncOutcome.failed:
      return report.error ?? 'Synchronizace se nepodařila. Zkus to znovu.';
    case DriveSyncOutcome.synced:
      if (report.uploaded > 0) {
        return 'Odesláno na Disk: ${czechDocs(report.uploaded)}.';
      }
      if (report.skipped > 0) return 'Na Disku je všechno aktuální.';
      return 'Zatím není co posílat — předmět potřebuje aspoň jedny výpisky '
          'nebo uloženou poznámku.';
  }
}

String czechDocs(int n) => switch (n) {
  1 => '1 dokument',
  2 || 3 || 4 => '$n dokumenty',
  _ => '$n dokumentů',
};

/// One row per synced doc: subject, when it last went up, and a way in.
class _DocStatusList extends ConsumerWidget {
  const _DocStatusList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(driveDocsProvider).valueOrNull ?? const [];
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];
    if (docs.isEmpty) return const SizedBox.shrink();
    final names = {
      for (final s in subjects)
        s.subject.id: (s.subject.fullName?.trim().isNotEmpty ?? false)
            ? s.subject.fullName!.trim()
            : s.subject.name,
    };
    final sorted = [...docs]
      ..sort((a, b) {
        final byName = (names[a.subjectId] ?? '').compareTo(
          names[b.subjectId] ?? '',
        );
        return byName != 0 ? byName : a.kind.index.compareTo(b.kind.index);
      });
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final doc in sorted)
            if (names.containsKey(doc.subjectId))
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.kind == DriveDocKind.notes
                                ? names[doc.subjectId]!
                                : '${names[doc.subjectId]} – přepisy',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            _status(doc),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: doc.error != null
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (doc.docId != null)
                      TextButton(
                        onPressed: () => _open(context, doc.docId!),
                        child: const Text('Otevřít'),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static String _status(DriveDoc doc) {
    final error = doc.error;
    if (error != null) return error;
    final at = doc.syncedAt;
    return at == null
        ? 'Čeká na odeslání'
        : 'Synchronizováno ${formatMeetingDate(at)}';
  }

  Future<void> _open(BuildContext context, String docId) async {
    final url = Uri.parse('https://docs.google.com/document/d/$docId/edit');
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      AppLog.e(_tag, 'could not open doc', e, st);
    }
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dokument se nepodařilo otevřít.')),
    );
  }
}

/// The part only the student can do: their own Google Cloud client.
Future<void> showDriveSetupGuide(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) =>
          _SetupGuide(scrollController: controller),
    ),
  );
}

class _SetupGuide extends ConsumerWidget {
  const _SetupGuide({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bundle = ref.watch(appBundleIdProvider);
    final bundleId = bundle.valueOrNull;

    Widget step(int n, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              '$n',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: Gap.xs),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
      children: [
        Text('Napojení na Google Disk', style: theme.textTheme.titleLarge),
        const SizedBox(height: Gap.sm),
        Text(
          'Dělá se jednou, na počítači je to pohodlnější. Všechno je zdarma.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Gap.xl),
        step(
          1,
          'Projekt',
          'Na console.cloud.google.com se přihlas účtem, kam se mají '
              'výpisky ukládat, a vytvoř nový projekt (třeba „Schůzky").',
        ),
        step(
          2,
          'Google Drive API',
          'APIs & Services › Library › „Google Drive API" › Enable.',
        ),
        step(
          3,
          'Přihlašovací obrazovka',
          'Google Auth Platform › Get started: název aplikace, tvůj e-mail, '
              'typ External. V Data access přidej rozsah '
              '„…/auth/drive.file". V Audience klepni na Publish app — bez '
              'toho přihlášení po 7 dnech vyprší. Google ji kvůli tomuhle '
              'rozsahu nekontroluje.',
        ),
        step(
          4,
          'Klient pro iPhone',
          'Clients › Create client › typ iOS. Do Bundle ID vlož přesně tohle:',
        ),
        Padding(
          padding: const EdgeInsets.only(left: 38, bottom: Gap.lg),
          child: bundleId == null
              ? Text(
                  bundle.isLoading
                      ? 'Zjišťuji…'
                      : 'Ukáže se až v aplikaci na iPhonu.',
                  style: theme.textTheme.bodyMedium,
                )
              : Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        bundleId,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Zkopírovat',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: bundleId));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Zkopírováno')),
                        );
                      },
                    ),
                  ],
                ),
        ),
        step(
          5,
          'Client ID',
          'Zkopíruj Client ID (končí na .apps.googleusercontent.com), vlož '
              'ho v Nastavení a klepni na „Přihlásit se Googlem".',
        ),
        step(
          6,
          'NotebookLM',
          'Po první synchronizaci je na Disku složka „Schůzky" s dokumentem '
              'pro každý předmět. V NotebookLM: Přidat zdroj › Disk Google. '
              'NotebookLM se sám neobnovuje — po nových hodinách klepni '
              'u zdroje na „Synchronizovat".',
        ),
        Text(
          'Když aplikaci nahraješ znovu pod jiným Bundle ID, musí se změnit '
          'i klient v kroku 4.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
