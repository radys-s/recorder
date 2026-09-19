import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// What actually leaves the app: a heading line and the text under it.
///
/// Most targets (a note app, a chat, NotebookLM) paste the body and ignore the
/// subject, so the title has to be inside the text as well or the recipient
/// gets a wall of words with no idea which lesson it is from.
String shareBody({required String title, required String content}) {
  final body = content.trim();
  final heading = title.trim();
  if (heading.isEmpty) return body;
  if (body.isEmpty) return heading;
  return '$heading\n\n$body';
}

/// Opens the system share sheet with plain text.
///
/// [context] is read for the origin rectangle: on an iPad the sheet is a
/// popover and iOS needs something to anchor it to. The iPhone ignores it.
Future<void> shareText(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      text: shareBody(title: title, content: content),
      subject: title,
      title: title,
      sharePositionOrigin: box == null || !box.hasSize
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}
