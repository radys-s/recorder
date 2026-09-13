import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'audio/foreground_recording_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The UI is Czech, so month and weekday names have to be too. Loading the
  // locale data up front keeps DateFormat from throwing the first time a list
  // row is built.
  Intl.defaultLocale = 'cs';
  await initializeDateFormatting('cs');

  // Lets the main isolate exchange messages with the service isolate, and must
  // run before any service is started. There is no service isolate on iOS —
  // see [ForegroundRecordingService] for why the whole plugin is Android-only
  // here — and this is the one call that lives outside that class.
  if (Platform.isAndroid) {
    FlutterForegroundTask.initCommunicationPort();
  }
  const ForegroundRecordingService().configure();

  runApp(const ProviderScope(child: RecorderApp()));
}
