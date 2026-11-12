import 'package:flutter_test/flutter_test.dart';
import 'package:yibubang/common/question_year_filter.dart';

void main() {
  group('parseQuestionYears', () {
    test('accepts strings, decorations and full-width digits', () {
      for (final value in ['2026', ' 2026年 ', '2026年度', '2026年真题',
        '年份：2026', '真题2026', '２０２６年']) {
        expect(parseQuestionYears(value), {2026}, reason: value);
      }
    });

    test('deduplicates multiple years and expands explicit inclusive ranges', () {
      expect(parseQuestionYears('2022、2024/2024；2026年'), {2022, 2024, 2026});
      expect(parseQuestionYears('2022–2026'), {2022, 2023, 2024, 2025, 2026});
      expect(parseQuestionYears('2022年至2024年'), {2022, 2023, 2024});
      expect(parseQuestionYears('2026-2026'), {2026});
    });

    test('unknown and malformed input never yield a guessed year', () {
      for (final value in <String?>[null, '', ' ', '未知', '模拟题', '0',
        '26', '1899', '2200', '12026', '20260', '2026.0', '202x',
        '2026-2022', '2026/未知', '2026,', '2026-27', '2026-02-01',
        '题号2026', '20262025', '2022--2026']) {
        expect(parseQuestionYears(value), isEmpty, reason: '$value');
      }
    });

    test('supported bounds are explicit and independent of current date', () {
      expect(parseQuestionYears('1900/2199'), {1900, 2199});
    });
  });

  group('QuestionYearCatalog', () {
    test('sorts distinct years descending and detects unknown metadata', () {
      final catalog = QuestionYearCatalog.fromValues(['2022', '2026/2024', '2022', null]);
      expect(catalog.years, [2026, 2024, 2022]);
      expect(catalog.hasUnknown, isTrue);
      expect(catalog.latestYear, 2026);
      expect(catalog.recentFiveLabel, '最近5年（2022–2026）');
    });

    test('recent five means five calendar years, not last five available years', () {
      final catalog = QuestionYearCatalog.fromValues(['2026', '2024', '2022', '2021', '2000']);
      expect(catalog.recentFiveYears, {2026, 2024, 2022});
      final historical = QuestionYearCatalog.fromValues(['2010', '2005']);
      expect(historical.recentFiveLabel, '最近5年（2006–2010）');
      expect(historical.recentFiveYears, {2010});
    });

    test('empty and all unknown chapters have no recent window', () {
      for (final values in <List<String?>>[[], [null, 'bad']]) {
        final catalog = QuestionYearCatalog.fromValues(values);
        expect(catalog.latestYear, isNull);
        expect(catalog.recentFiveYears, isEmpty);
        expect(catalog.recentFiveLabel, '最近5年（无有效年份）');
        expect(catalog.hasUnknown, values.isNotEmpty);
      }
    });
  });

  group('QuestionYearFilter', () {
    final catalog = QuestionYearCatalog.fromValues(['2026', '2022', '2021', null]);

    test('all is the default including unknown; explicit empty means none', () {
      const all = QuestionYearFilter.all();
      final none = QuestionYearFilter.selected({});
      for (final value in <String?>['2026', '2021', null, 'bad']) {
        expect(all.matches(value, catalog), isTrue);
        expect(none.matches(value, catalog), isFalse);
      }
    });

    test('selection uses any-year intersection without duplicating questions', () {
      final filter = QuestionYearFilter.selected({2022, 2026});
      final input = ['2022/2026', '2021', '2026', null];
      expect(input.where((year) => filter.matches(year, catalog)).toList(),
          ['2022/2026', '2026']);
      expect(filter.matches('2021–2023', catalog), isTrue);
    });

    test('unknown is independently selectable and combinable', () {
      final onlyUnknown = QuestionYearFilter.selected({}, includeUnknown: true);
      expect(onlyUnknown.matches(null, catalog), isTrue);
      expect(onlyUnknown.matches('broken', catalog), isTrue);
      expect(onlyUnknown.matches('2026', catalog), isFalse);
      final combined = QuestionYearFilter.selected({2026}, includeUnknown: true);
      expect(combined.matches('2026', catalog), isTrue);
      expect(combined.matches('', catalog), isTrue);
    });

    test('recent window is inclusive and excludes unknown', () {
      const filter = QuestionYearFilter.recentFive();
      expect(filter.matches('2022', catalog), isTrue);
      expect(filter.matches('2026', catalog), isTrue);
      expect(filter.matches('2021', catalog), isFalse);
      expect(filter.matches(null, catalog), isFalse);
    });

    test('recent intent rebases on destination chapter, explicit years do not', () {
      final other = QuestionYearCatalog.fromValues(['2015', '2011', '2010']);
      const recent = QuestionYearFilter.recentFive();
      expect(recent.matches('2011', other), isTrue);
      expect(recent.matches('2010', other), isFalse);
      expect(QuestionYearFilter.selected({2026}).matches('2015', other), isFalse);
    });

    test('chip toggles do not mutate existing selection', () {
      const all = QuestionYearFilter.all();
      final one = all.toggleYear(2026, catalog);
      expect(one.years, {2026});
      expect(one.includeUnknown, isFalse);
      final two = one.toggleYear(2022, catalog);
      expect(two.years, {2026, 2022});
      expect(one.years, {2026});
      expect(two.toggleYear(2026, catalog).years, {2022});
      expect(one.toggleYear(2026, catalog).matches('2026', catalog), isFalse);
      expect(all.toggleUnknown(catalog).years, isEmpty);
      expect(all.toggleUnknown(catalog).includeUnknown, isTrue);
    });

    test('editing recent years converts to an explicit selection', () {
      final edited = const QuestionYearFilter.recentFive().toggleYear(2021, catalog);
      expect(edited.isRecentFive, isFalse);
      expect(edited.years, {2026, 2022, 2021});
      final withUnknown = const QuestionYearFilter.recentFive().toggleUnknown(catalog);
      expect(withUnknown.years, {2026, 2022});
      expect(withUnknown.includeUnknown, isTrue);
    });
  });
}
