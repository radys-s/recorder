import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recorder/core/theme.dart';
import 'package:recorder/data/db/app_database.dart';
import 'package:recorder/features/notes_library/notes_library_screen.dart';
import 'package:recorder/features/search/search_screen.dart';
import 'package:recorder/features/subjects/subjects_screen.dart';

/// Only synthetic in-memory data. PNGs are local UI evidence, never device proof.
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('cs');
    final fonts = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    await fonts.load();
    await (FontLoader('BricolageGrotesque')
      ..addFont(rootBundle.load('assets/fonts/BricolageGrotesque-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/BricolageGrotesque-ExtraBold.ttf'))).load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 390.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'synthetic previews $width dark=$dark, large text + reduced motion',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = Size(width, width == 320 ? 640 : 844);
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          final subject = await db.savedNotesDao.createFolder(
            'Dějiny středověké Evropy',
          );
          await db.savedNotesDao.saveNote(
            title: 'Syntetická hodina: společnost a vzdělávání',
            content: 'Středověká společnost se měnila. Školy a univerzity pomáhaly rozvoji vědění.',
            folderId: subject,
          );
          try {
            for (final entry in <String, Widget>{
              'library': const NotesLibraryScreen(),
              'subjects': const SubjectsScreen(),
              'search': const SearchScreen(),
            }.entries) {
              final boundary = GlobalKey();
              await t.pumpWidget(
                ProviderScope(
                  overrides: [appDatabaseProvider.overrideWithValue(db)],
                  child: MaterialApp(
                    theme: dark ? appDarkTheme : appLightTheme,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        disableAnimations: true,
                        textScaler: TextScaler.linear(1.8),
                      ),
                      child: child!,
                    ),
                    home: RepaintBoundary(key: boundary, child: entry.value),
                  ),
                ),
              );
              Future<void> settle() async {
                for (var i = 0; i < 15; i++) {
                  await t.runAsync(
                    () =>
                        Future<void>.delayed(const Duration(milliseconds: 10)),
                  );
                  await t.pump(const Duration(milliseconds: 100));
                }
              }

              await settle();
              if (entry.key == 'search') {
                await t.enterText(find.byType(TextField), 'stredoveka');
                await settle();
              }
              expect(t.takeException(), isNull);
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              await t.runAsync(() async {
                final image = await render.toImage(pixelRatio: 1);
                final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
                final dir = Directory('.dart_tool/m60-previews');
                await dir.create(recursive: true);
                await File(
                  '${dir.path}/${entry.key}-${width.toInt()}-${dark ? 'dark' : 'light'}.png',
                ).writeAsBytes(bytes.buffer.asUint8List());
                image.dispose();
              });
              await t.pumpWidget(const SizedBox());
              await t.pump(const Duration(seconds: 1));
            }
          } finally {
            await t.pumpWidget(const SizedBox());
            await t.pump(const Duration(seconds: 1));
            await db.close();
          }
        },
      );
    }
  }
}
