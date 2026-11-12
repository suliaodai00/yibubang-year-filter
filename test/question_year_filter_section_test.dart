import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibubang/common/question_year_filter.dart';
import 'package:yibubang/widgets/question_year_filter_section.dart';

void main() {
  for (final width in [320.0, 1000.0]) {
    testWidgets('year chips wrap and combine at width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final catalog = QuestionYearCatalog.fromValues(['2026', '2022', '2021', null]);
      QuestionYearFilter filter = const QuestionYearFilter.all();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: StatefulBuilder(
          builder: (context, setState) => QuestionYearFilterSection(
            catalog: catalog,
            filter: filter,
            onChanged: (next) => setState(() => filter = next),
          ),
        ))),
      ));
      expect(find.text('年份（可多选）'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '全部年份')).selected, isTrue);
      await tester.tap(find.text('2026年'));
      await tester.pump();
      await tester.tap(find.text('2022年'));
      await tester.pump();
      expect(filter.years, {2026, 2022});
      await tester.tap(find.text('年份未知'));
      await tester.pump();
      expect(filter.includeUnknown, isTrue);
      expect(filter.years, {2026, 2022});
      await tester.tap(find.text('最近5年（2022–2026）'));
      await tester.pump();
      expect(filter.isRecentFive, isTrue);
      expect(filter.includeUnknown, isFalse);
      await tester.tap(find.text('2026年'));
      await tester.pump();
      expect(filter.isRecentFive, isFalse);
      expect(filter.years, {2022});
      await tester.tap(find.text('2022年'));
      await tester.pump();
      expect(filter.isAll, isFalse);
      expect(filter.years, isEmpty);
      await tester.tap(find.text('全部年份'));
      await tester.pump();
      expect(filter.isAll, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('recent shortcut disabled for all unknown chapter', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: QuestionYearFilterSection(
        catalog: QuestionYearCatalog.fromValues([null, 'bad']),
        filter: const QuestionYearFilter.all(),
        onChanged: (_) => fail('Disabled shortcut must not change filter'),
      ),
    )));
    final recent = find.widgetWithText(ChoiceChip, '最近5年（无有效年份）');
    expect(tester.widget<ChoiceChip>(recent).onSelected, isNull);
    expect(find.text('年份未知'), findsOneWidget);
    expect(find.byType(FilterChip), findsOneWidget);
  });
}
