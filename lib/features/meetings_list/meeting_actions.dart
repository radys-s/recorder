import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/recording_controller.dart';
import '../../core/logging.dart';
import '../../core/paths.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/db/app_database.dart';
import '../../data/meeting_deleter.dart';

const _tag = 'meetings.actions';

final meetingDeleterProvider = Provider<MeetingDeleter>((ref) {
  return MeetingDeleter(
    ref.watch(appDatabaseProvider).meetingsDao,
    isRecording: (id) {
      final state = ref.read(recordingControllerProvider);
      return state.isRecording && state.meetingId == id;
    },
    documentsPath: documentsPath,
  );
});

/// `Schůzka 14.09. 10:30` — the title a recording gets when nobody names it.
/// The list shows the time instead of a title like this, since the day heading
/// above the row already says the rest.
bool isDefaultMeetingTitle(String title) =>
    RegExp(r'^(?:Schůzka|Hodina) \d{2}\.\d{2}\. \d{2}:\d{2}$').hasMatch(title);

/// Asks, then deletes the meeting with its audio, transcript, answers and
/// notes. Saved notes in the library stay.
///
/// With [popRoute] the current route — the meeting's own screen — is closed
/// *before* the delete, so it never renders a meeting that is half gone.
/// Everything that is needed afterwards is captured up front, because the
/// screen's `ref` and `context` die with the route.
Future<void> confirmAndDeleteMeeting(
  BuildContext context,
  WidgetRef ref, {
  required int meetingId,
  bool popRoute = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final recording = ref.read(recordingControllerProvider);
  if (recording.isRecording && recording.meetingId == meetingId) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Nahrávanou schůzku nejde smazat. Nejdřív ji zastav.'),
      ));
    return;
  }

  final confirmed = await showConfirmDialog(
    context,
    icon: Icons.delete_outline,
    title: 'Smazat schůzku?',
    message: 'Smaže se nahrávka, přepis, odpovědi i vygenerované poznámky. '
        'Poznámky uložené v knihovně zůstanou.',
    confirmLabel: 'Smazat',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;

  final deleter = ref.read(meetingDeleterProvider);
  if (popRoute) Navigator.of(context).pop();

  try {
    await deleter.delete(meetingId);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Schůzka je smazaná.')));
  } catch (e, st) {
    AppLog.e(_tag, 'meeting $meetingId: delete failed', e, st);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Schůzku se nepodařilo smazat.')),
      );
  }
}

Future<void> renameMeetingFlow(
  BuildContext context,
  WidgetRef ref,
  Meeting meeting,
) async {
  final dao = ref.read(appDatabaseProvider).meetingsDao;
  final name = await showTextInputDialog(
    context,
    title: 'Přejmenovat schůzku',
    label: 'Název',
    initialValue: meeting.title,
    maxLength: 80,
  );
  if (name == null || name == meeting.title) return;
  await dao.renameMeeting(meeting.id, name);
}
