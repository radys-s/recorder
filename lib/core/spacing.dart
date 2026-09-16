/// The 4pt spacing scale.
///
/// Before this file the app used ten different gap sizes (4, 5, 6, 8, 10, 12,
/// 13, 16, 20, 32) chosen one `EdgeInsets` at a time, which is why nothing
/// quite lined up between screens. Everything new picks from here.
abstract final class Gap {
  const Gap._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Bottom padding for any scrollable that sits under a floating action
  /// button, so the last row can be scrolled clear of it. Was a bare `96`
  /// repeated in three files.
  static const double fabClearance = 96;

  /// Corner radius for cards and other raised surfaces. Kept here rather than
  /// in the theme because a few widgets need the number itself (clipping an
  /// ink splash, matching a container to the card behind it).
  static const double radius = 20;

  /// Corner radius for bottom sheets and hero surfaces.
  static const double sheetRadius = 28;
}
