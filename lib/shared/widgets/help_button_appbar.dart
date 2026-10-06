import 'package:flutter/material.dart';
import '../../core/utils/safe_area_utils.dart';
import '../../core/theme/app_theme.dart';

/// Función helper para crear un IconButton de Help reutilizable para AppBar.
/// Muestra un modal bottom sheet con título y tips según la pestaña activa.
///
/// Uso:
/// ```
/// IconButton(
///   tooltip: 'Ayuda',
///   onPressed: () => showHelpBottomSheet(
///     context: context,
///     titles: _titles,
///     helpTexts: _helpTexts,
///     activeTabIndex: _tabController.index,
///   ),
///   icon: const Icon(Icons.help_outline),
/// ),
/// ```
void showHelpBottomSheet({
  required BuildContext context,
  required List<String> titles,
  required List<String> helpTexts,
  required int activeTabIndex,
}) {
  final idx = activeTabIndex.clamp(0, titles.length - 1);

  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: SafeAreaUtils.bottomSheetPadding(ctx),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titles[idx],
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(helpTexts[idx], style: Theme.of(ctx).textTheme.bodyMedium),
        ],
      ),
    ),
  );
}
