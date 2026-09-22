import 'package:flutter/widgets.dart';

class SafeAreaUtils {
  const SafeAreaUtils._();

  static double safeBottomInset(BuildContext context, {double extra = 0}) {
    final media = MediaQuery.of(context);
    final systemInset = media.viewPadding.bottom > media.padding.bottom
        ? media.viewPadding.bottom
        : media.padding.bottom;
    return systemInset + extra;
  }

  static EdgeInsets bottomSheetPadding(
    BuildContext context, {
    double horizontal = 24,
    double top = 20,
    double bottomExtra = 24,
  }) {
    return EdgeInsets.fromLTRB(
      horizontal,
      top,
      horizontal,
      safeBottomInset(context, extra: bottomExtra),
    );
  }
}
