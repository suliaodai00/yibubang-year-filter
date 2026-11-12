import 'package:flutter/material.dart';

import '../common/question_year_filter.dart';

/// Wraps on narrow screens; the surrounding drawer provides vertical scrolling.
class QuestionYearFilterSection extends StatelessWidget {
  final QuestionYearCatalog catalog;
  final QuestionYearFilter filter;
  final ValueChanged<QuestionYearFilter> onChanged;

  const QuestionYearFilterSection({
    super.key,
    required this.catalog,
    required this.filter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = filter.selectedYears(catalog);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('年份（可多选）', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('全部年份'),
                selected: filter.isAll,
                onSelected: (_) => onChanged(const QuestionYearFilter.all()),
              ),
              ChoiceChip(
                label: Text(catalog.recentFiveLabel),
                selected: filter.isRecentFive,
                onSelected: catalog.latestYear == null ? null : (_) =>
                    onChanged(const QuestionYearFilter.recentFive()),
              ),
              for (final year in catalog.years)
                FilterChip(
                  label: Text('$year年'),
                  selected: !filter.isAll && selected.contains(year),
                  onSelected: (_) => onChanged(filter.toggleYear(year, catalog)),
                ),
              if (catalog.hasUnknown)
                FilterChip(
                  label: const Text('年份未知'),
                  selected: !filter.isAll && filter.includeUnknown,
                  onSelected: (_) => onChanged(filter.toggleUnknown(catalog)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '最近5年以本章节最新有效年份为准；未知含缺失或无法识别的年份。'
            '筛选仅本次页面有效，跨章节保留选择；最近5年按新章节重算。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
