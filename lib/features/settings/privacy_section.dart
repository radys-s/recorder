import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../audio/recording_controller.dart';
import '../../core/providers.dart';
import '../../core/redaction.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/inset_group.dart';
import '../../core/widgets/section_header.dart';
import '../../data/data_privacy.dart';
import '../../data/recovery_backup.dart'
    if (dart.library.js_interop) '../../data/recovery_backup_stub.dart';
import '../../data/db/app_database.dart';
import '../../legal/data_processors.dart';
import '../legal/about_screen.dart';
import '../legal/data_processor_notice.dart';

/// Settings › Soukromí a data: where data goes, export, delete everything,
/// and O aplikaci.
class PrivacySection extends ConsumerStatefulWidget {
  const PrivacySection({super.key});

  @override
  ConsumerState<PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends ConsumerState<PrivacySection> {
  bool _busy = false;

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showProcessors() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text(
              'Kam data odcházejí',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Aplikace nemá server. Data jdou jen do služeb, jejichž klíč '
              'vyplníš, a na Google Disk, když zapneš synchronizaci.',
            ),
            for (final processor in DataProcessor.values) ...[
              const Divider(height: 32),
              DataProcessorDetails(processor),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final data = await exportAllData(ref.read(appDatabaseProvider), now: now);
      final dir = await getTemporaryDirectory();
      final name =
          'aftermind-export-${DateFormat('yyyy-MM-dd').format(now)}.json';
      final file = File(p.join(dir.path, name));
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Aftermind – export dat',
          sharePositionOrigin: box == null || !box.hasSize
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e) {
      _notify('Export se nepovedl: ${userMessage(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backup() async {
    if (ref.read(recordingControllerProvider).isRecording) {
      _notify('Nejdřív ukonči nahrávání a počkej na uložení.');
      return;
    }
    setState(() => _busy = true);
    try {
      final docs = await getApplicationDocumentsDirectory();
      final temporary = await getTemporaryDirectory();
      final dir = await temporary.createTemp('aftermind-recovery-share-');
      final file = await RecoveryBackup.create(
        documents: docs,
        destination: File(p.join(dir.path, 'aftermind-recovery.zip')),
        snapshotTo: (path) => ref.read(appDatabaseProvider).customStatement(
          'VACUUM INTO ?',
          [path],
        ),
      );
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/zip')],
          subject: 'Aftermind – soukromá záloha včetně zvuku',
          sharePositionOrigin: box == null || !box.hasSize
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      _notify(
        result.status == ShareResultStatus.success
            ? 'Záloha byla ověřena. Před aktualizací zkontroluj uloženou kopii mimo telefon.'
            : 'Záloha byla ověřena, ale její uložení mimo telefon nebylo potvrzeno.',
      );
    } catch (e) {
      _notify('Zálohu se nepodařilo ověřit: ${userMessage(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _wipe() async {
    if (ref.read(recordingControllerProvider).isRecording) {
      _notify('Nejdřív ukonči nahrávání.');
      return;
    }
    final first = await showConfirmDialog(
      context,
      title: 'Smazat všechna data?',
      message:
          'Smažou se všechny hodiny, nahrávky, přepisy, výpisky, poznámky, '
          'předměty, kartičky, uložené klíče a přihlášení ke Googlu. '
          'Dokumenty na Google Disku zůstanou.',
      confirmLabel: 'Pokračovat',
      destructive: true,
      icon: Icons.delete_forever_outlined,
    );
    if (!first || !mounted) return;
    final second = await showConfirmDialog(
      context,
      title: 'Opravdu? Nejde to vrátit.',
      message: 'Pokud si chceš něco nechat, nejdřív ulož zálohu včetně zvuku mimo telefon.',
      confirmLabel: 'Smazat vše',
      destructive: true,
    );
    if (!second || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(dataWiperProvider).wipe();
      ref
        ..invalidate(hasApiKeyProvider)
        ..invalidate(maskedApiKeyProvider)
        ..invalidate(hasGeminiKeyProvider)
        ..invalidate(hasVisionKeyProvider);
      if (!mounted) return;
      // Back to the root, where the consent screen now waits.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _notify('Mazání se nepovedlo celé: ${userMessage(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Soukromí a data',
          description:
              'Všechno je uložené jen v tomhle telefonu. Autor aplikace '
              'k tvým datům nemá přístup.',
        ),
        InsetGroup(
          dividerIndent: ListRow.textIndent + 12,
          horizontalInset: 0,
          children: [
            ListRow(
              leadingSlot: ListRow.leadingWidth + 12,
              title: 'Kam data odcházejí',
              leading: const Icon(Icons.hub_outlined),
              chevron: true,
              onTap: _busy ? null : _showProcessors,
            ),
            ListRow(
              leadingSlot: ListRow.leadingWidth + 12,
              title: _busy ? 'Pracuji s daty…' : 'Záloha včetně zvuku',
              subtitle: 'Ověřený ZIP pro obnovu; obsahuje soukromé nahrávky a fotografie, ne klíče. Ulož mimo telefon.',
              leading: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.backup_outlined),
              chevron: true,
              onTap: _busy ? null : _backup,
            ),
            ListRow(
              leadingSlot: ListRow.leadingWidth + 12,
              title: 'Exportovat texty',
              subtitle:
                  'JSON bez zvuku a fotografií. Není to obnovitelná záloha.',
              leading: const Icon(Icons.ios_share_outlined),
              chevron: true,
              onTap: _busy ? null : _export,
            ),
            ListRow(
              leadingSlot: ListRow.leadingWidth + 12,
              title: 'Smazat všechna data',
              titleColor: error,
              leading: Icon(Icons.delete_forever_outlined, color: error),
              onTap: _busy ? null : _wipe,
            ),
            ListRow(
              leadingSlot: ListRow.leadingWidth + 12,
              title: 'O aplikaci',
              leading: const Icon(Icons.info_outline),
              chevron: true,
              onTap: () => Navigator.of(context).push(AboutScreen.route()),
            ),
          ],
        ),
      ],
    );
  }
}
