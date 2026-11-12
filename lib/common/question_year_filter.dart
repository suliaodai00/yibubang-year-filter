/// Year metadata is deliberately parsed conservatively: unrecognised or partly
/// malformed values belong to “年份未知”, never to a guessed year. Supported
/// years are 1900–2199; no device clock is involved.
Set<int> parseQuestionYears(String? value) {
  if (value == null || value.trim().isEmpty) return const <int>{};
  final normalized = value.replaceAllMapped(RegExp('[０-９]'), (match) {
    return String.fromCharCode(match[0]!.codeUnitAt(0) - 0xfee0);
  }).trim();
  const year = r'((?:19|20|21)\d{2})';
  final single = RegExp(
    '^' r'(?:年份[：:]?\s*|真题\s*)?' + year +
        r'\s*(?:年(?:真题|考题)?|年度|真题)?' r'$',
  );
  final range = RegExp('^' + year + r'\s*年?\s*[-–—~～至到]\s*' +
      year + r'\s*年?$');
  final result = <int>{};
  for (final part in normalized.split(RegExp(r'[,，、/;；|]+'))) {
    final token = part.trim();
    final rangeMatch = range.firstMatch(token);
    if (rangeMatch != null) {
      final start = int.parse(rangeMatch[1]!);
      final end = int.parse(rangeMatch[2]!);
      if (start > end) return const <int>{};
      for (var y = start; y <= end; y++) {
        result.add(y);
      }
      continue;
    }
    final match = single.firstMatch(token);
    if (match == null) return const <int>{};
    result.add(int.parse(match[1]!));
  }
  return Set<int>.unmodifiable(result);
}

/// Derived from ALL questions in a chapter, before any other filters.
class QuestionYearCatalog {
  final List<int> years;
  final bool hasUnknown;

  QuestionYearCatalog._(Iterable<int> years, this.hasUnknown)
      : years = List<int>.unmodifiable(years.toList()..sort((a, b) => b.compareTo(a)));

  factory QuestionYearCatalog.fromValues(Iterable<String?> values) {
    final years = <int>{};
    var hasUnknown = false;
    for (final value in values) {
      final parsed = parseQuestionYears(value);
      hasUnknown = hasUnknown || parsed.isEmpty;
      years.addAll(parsed);
    }
    return QuestionYearCatalog._(years, hasUnknown);
  }

  int? get latestYear => years.isEmpty ? null : years.first;
  Set<int> get recentFiveYears => latestYear == null
      ? const <int>{}
      : years.where((y) => y >= latestYear! - 4).toSet();
  String get recentFiveLabel => latestYear == null
      ? '最近5年（无有效年份）'
      : '最近5年（${latestYear! - 4}–$latestYear）';
}

/// Empty explicit selection means NONE, not all. All is a separate mode.
/// Recent-five is an intent resolved against each destination chapter.
class QuestionYearFilter {
  final bool isAll;
  final bool isRecentFive;
  final Set<int> years;
  final bool includeUnknown;

  const QuestionYearFilter.all()
      : isAll = true,
        isRecentFive = false,
        years = const <int>{},
        includeUnknown = true;

  const QuestionYearFilter.recentFive()
      : isAll = false,
        isRecentFive = true,
        years = const <int>{},
        includeUnknown = false;

  QuestionYearFilter.selected(Iterable<int> years, {this.includeUnknown = false})
      : isAll = false,
        isRecentFive = false,
        years = Set<int>.unmodifiable(years);

  Set<int> selectedYears(QuestionYearCatalog catalog) => isAll
      ? catalog.years.toSet()
      : isRecentFive ? catalog.recentFiveYears : years;

  bool matches(String? value, QuestionYearCatalog catalog) {
    if (isAll) return true;
    final parsed = parseQuestionYears(value);
    if (parsed.isEmpty) return includeUnknown;
    return parsed.any(selectedYears(catalog).contains);
  }

  /// From All, choosing a chip starts an explicit selection of that chip.
  /// From Recent, choosing a chip edits the resolved recent-five selection.
  QuestionYearFilter toggleYear(int year, QuestionYearCatalog catalog) {
    final selected = isAll ? <int>{} : selectedYears(catalog).toSet();
    if (!selected.add(year)) selected.remove(year);
    return QuestionYearFilter.selected(selected,
        includeUnknown: !isAll && includeUnknown);
  }

  QuestionYearFilter toggleUnknown(QuestionYearCatalog catalog) =>
      QuestionYearFilter.selected(isAll ? <int>{} : selectedYears(catalog),
          includeUnknown: isAll || !includeUnknown);
}
