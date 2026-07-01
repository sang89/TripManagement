import 'package:flutter/material.dart';
import 'breakpoints.dart';

/// Shows a bottom sheet on mobile (< 900 px) and a centered rounded dialog on
/// desktop/tablet (≥ 900 px), matching the PropertyManagement pattern.
///
/// The builder receives the inner BuildContext. On desktop the content is
/// clipped inside a rounded Dialog so the builder does not need to add its own
/// rounded corners or background — they are provided by the Dialog itself.
///
/// Optional [maxWidth] / [maxHeight] override the default dialog constraints
/// (560 × 700) for sheets that need extra space (e.g. score entry, brackets).
Future<T?> showResponsiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 560,
  double maxHeight = 700,
}) {
  if (isDesktop(context)) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
          child: builder(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}
