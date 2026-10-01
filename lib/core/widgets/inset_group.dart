import 'package:flutter/material.dart';

import '../accent.dart';
import '../spacing.dart';
import 'pressable.dart';

/// An iOS-style inset group: a small caps label, then rows on one rounded
/// surface with hairlines indented under the text.
///
/// Content without boxes: the rows share a single surface instead of each
/// being its own card, so hierarchy comes from the label and the type rather
/// than from borders.
class InsetGroup extends StatelessWidget {
  const InsetGroup({
    super.key,
    this.label,
    this.trailingLabel,
    required this.children,
    this.dividerIndent = ListRow.textIndent,
    this.horizontalInset = Gap.lg,
  });

  final String? label;

  /// Optional right-aligned note next to the label, e.g. a count.
  final String? trailingLabel;
  final List<Widget> children;

  /// Where the hairline starts, measured from the group's left edge.
  final double dividerIndent;

  /// Space on each side. Zero inside a list that is already padded.
  final double horizontalInset;

  static const radius = 22.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalInset + Gap.lg,
              Gap.xl,
              horizontalInset + Gap.lg,
              Gap.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(label!.toUpperCase(), style: labelStyle),
                  ),
                ),
                if (trailingLabel != null)
                  Text(trailingLabel!, style: labelStyle),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalInset),
          // The group's edge is the accent's hairline gradient, the same light
          // source every card in the app has.
          child: GradientOutline(
            gradient: context.accent.hairline(
              scheme.outlineVariant.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.5 : 0.65,
              ),
            ),
            borderRadius: BorderRadius.circular(radius),
            width: 0.8,
            child: Material(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(radius),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 0.5,
                        thickness: 0.5,
                        indent: dividerIndent,
                        color: scheme.outlineVariant.withValues(alpha: 0.8),
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One row of an [InsetGroup]: a small leading mark, a title, an optional
/// subtitle and excerpt, and a trailing value with a chevron.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.titleColor,
    this.leading,
    this.subtitle,
    this.subtitleColor,
    this.excerpt,
    this.excerptSpan,
    this.status,
    this.statusColor,
    this.trailing,
    this.chevron = true,
    this.onTap,
    this.onLongPress,
    this.leadingSlot = leadingWidth,
  });

  /// Left padding plus the leading slot: where the title starts, and so where
  /// the hairline between rows starts.
  static const textIndent = Gap.lg + leadingWidth;
  static const leadingWidth = 24.0;

  final String title;

  /// A destructive row („Smazat…") takes the error colour.
  final Color? titleColor;
  final Widget? leading;
  final String? subtitle;
  final Color? subtitleColor;

  /// Up to two lines of prose under the subtitle.
  final String? excerpt;

  /// Rich text in place of [excerpt], e.g. a search hit with the match marked.
  final InlineSpan? excerptSpan;

  /// A short state line (errors, progress) under everything else.
  final String? status;
  final Color? statusColor;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Width of the leading slot; wider for an icon tile than for a dot. The
  /// group's divider indent should be `Gap.lg + leadingSlot`.
  final double leadingSlot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;

    // One node per row, announced as a button, instead of a loose run of
    // texts a screen reader cannot activate.
    final row = MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.md - 1,
                Gap.md,
                Gap.md - 1,
              ),
              child: Row(
                crossAxisAlignment: excerpt == null && excerptSpan == null
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: leadingSlot,
                    child: Align(
                      alignment: excerpt == null && excerptSpan == null
                          ? Alignment.centerLeft
                          : const Alignment(-1, -0.6),
                      child: leading,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 17,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                            color: titleColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: subtitleColor ?? muted,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        ],
                        if (excerptSpan != null) ...[
                          const SizedBox(height: Gap.xs),
                          Text.rich(
                            excerptSpan!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.78),
                              fontSize: 15,
                              height: 1.35,
                            ),
                          ),
                        ] else if (excerpt != null && excerpt!.isNotEmpty) ...[
                          const SizedBox(height: Gap.xs),
                          Text(
                            excerpt!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.78),
                              fontSize: 15,
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (status != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            status!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: statusColor ?? muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: Gap.sm),
                    trailing!,
                  ],
                  if (chevron) ...[
                    const SizedBox(width: Gap.xs),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: muted.withValues(alpha: 0.6),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // A row that does something sinks a little under the finger; a plain
    // read-only row stays still.
    return onTap == null && onLongPress == null
        ? row
        : Pressable(scale: 0.985, child: row);
  }
}

/// A subject's colour as a small dot, the leading mark of a lesson row —
/// a lit gradient rather than a flat disc.
class SubjectDot extends StatelessWidget {
  const SubjectDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: subjectGradient(color),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: size * 0.6),
      ],
    ),
  );
}

/// A rounded tile carrying an icon on a gradient: the leading mark of a
/// subject or a note row. With [color] it uses the subject's colour, else the
/// accent.
class GradientIconTile extends StatelessWidget {
  const GradientIconTile({
    super.key,
    required this.icon,
    this.color,
    this.size = 36,
  });

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final gradient = color == null
        ? accent.fillGradient
        : subjectGradient(color!);
    final glow = color ?? accent.fill;
    final onColor = color == null
        ? accent.onFill
        : (ThemeData.estimateBrightnessForColor(color!) == Brightness.dark
              ? Colors.white
              : Colors.black87);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.55, color: onColor),
    );
  }
}
