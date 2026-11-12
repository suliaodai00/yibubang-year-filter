import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yibubang/db/database_helper.dart';
import 'package:yibubang/models/chapter.dart';
import 'package:yibubang/models/question.dart';
import 'package:yibubang/screens/question_detail_page.dart';
import 'package:yibubang/screens/question_grid_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Database bank;
  late Database records;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'identityId': 'i', 'activeBankId': 'test',
      'mode': 0, 'cutType': 0, 'questionType': 0, 'category': 0,
    });
    bank = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    records = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    DatabaseHelper.setDatabaseForTesting(bank);
    UserDBHelper.setDatabaseForTesting(records);
    await bank.execute('CREATE TABLE Question (id TEXT PRIMARY KEY, year TEXT, '
        'type TEXT, title TEXT, option TEXT, answer TEXT, chapter_id TEXT)');
    await bank.execute('CREATE TABLE IdentityQuestion (identity_id TEXT, '
        'subject_id TEXT, chapter_id TEXT, question_id TEXT)');
    // No siblings: these tables let sibling loading complete without I/O.
    await bank.execute('CREATE TABLE Chapter (id TEXT, name TEXT)');
    await bank.execute('CREATE TABLE IdentityChapter (identity_id TEXT, '
        'subject_id TEXT, chapter_id TEXT, total INTEGER)');
    await records.execute('CREATE TABLE Question (id TEXT PRIMARY KEY, '
        'chapter_id TEXT, chapter_parent_id TEXT, cut_question TEXT, '
        'user_answer TEXT, status INTEGER, collection INTEGER, updated_at INTEGER)');
    final years = <String?>['2026', '2022', '2021', null, '2022/2026'];
    for (var i = 0; i < years.length; i++) {
      final id = 'q${i + 1}';
      await bank.insert('Question', {
        'id': id, 'year': years[i], 'type': '1', 'title': 'Test $id',
        'option': '[{"key":"A","title":"A"},{"key":"B","title":"B"}]',
        'answer': 'A', 'chapter_id': 'c',
      });
      await bank.insert('IdentityQuestion', {
        'identity_id': 'i', 'subject_id': 's', 'chapter_id': 'c', 'question_id': id,
      });
      await records.insert('Question', UserQuestion(
        id: id, chapterId: 'c', chapterParentId: 's', userAnswer: '',
        status: 0, collection: i == 1 ? 1 : 0,
      ).toMap());
    }
  });

  tearDown(() async {
    DatabaseHelper.setDatabaseForTesting(null);
    UserDBHelper.setDatabaseForTesting(null);
    await bank.close();
    await records.close();
  });

  // SQLite FFI uses real async work outside the widget test's fake clock.
  Future<void> settleDatabase(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpGrid(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: QuestionGridPage(chapter: Chapter(
      id: 'c', name: 'Year tests', subjectId: 's', identityId: 'i',
      correct: 0, incorrect: 0, total: 5,
    ))));
    await settleDatabase(tester);
  }

  Future<void> openDrawer(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> closeDrawer(WidgetTester tester) async {
    final state = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    state.closeEndDrawer();
    await tester.pumpAndSettle();
  }

  testWidgets('count, original numbers, navigation and destination filtering agree', (tester) async {
    final before = await tester.runAsync(() => records.query('Question', orderBy: 'id'));
    await pumpGrid(tester);
    expect(find.text('当前筛选：5题'), findsOneWidget);
    await openDrawer(tester);
    await choose(tester, '最近5年（2022–2026）');
    await closeDrawer(tester);
    expect(find.text('当前筛选：3题'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '1'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '2'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '5'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '3'), findsNothing);
    await tester.tap(find.widgetWithText(ElevatedButton, '2'));
    await tester.pumpAndSettle();
    final detail = tester.widget<QuestionDetailPage>(find.byType(QuestionDetailPage));
    expect(detail.questions.map((q) => q.id), ['q1', 'q2', 'q5']);
    expect(detail.userQuestions.map((q) => q.id), ['q1', 'q2', 'q5']);
    expect(detail.questionIndex, 1);
    // This is the same callback used by detail-page chapter navigation.
    final nextQuestions = [
      Question(id: 'n1', year: '2015', userAnswer: ''),
      Question(id: 'n2', year: '2011', userAnswer: ''),
      Question(id: 'n3', year: '2010', userAnswer: ''),
    ];
    final nextUsers = nextQuestions.reversed.map((q) => UserQuestion(
      id: q.id, chapterId: 'next', chapterParentId: 's',
      userAnswer: '', status: 0, collection: 0,
    )).toList();
    final next = await detail.chapterQuestionFilter!(nextQuestions, nextUsers);
    expect(next.key.map((q) => q.id), ['n1', 'n2']);
    expect(next.value.map((q) => q.id), ['n1', 'n2']);
    expect(await tester.runAsync(() => records.query('Question', orderBy: 'id')), before);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('unknown, empty selection and existing collection classification intersect', (tester) async {
    await pumpGrid(tester);
    await openDrawer(tester);
    await choose(tester, '年份未知');
    await closeDrawer(tester);
    expect(find.text('当前筛选：1题'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '4'), findsOneWidget);
    await openDrawer(tester);
    await choose(tester, '年份未知');
    await closeDrawer(tester);
    expect(find.text('当前筛选：0题'), findsOneWidget);
    await openDrawer(tester);
    await choose(tester, '2022年');
    await closeDrawer(tester);
    expect(find.text('当前筛选：2题'), findsOneWidget);
    // Simulate the persisted existing collection category on a fresh page.
    await tester.pumpWidget(const SizedBox.shrink());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('category', 2);
    await pumpGrid(tester);
    await openDrawer(tester);
    await choose(tester, '2026年');
    await closeDrawer(tester);
    expect(find.text('当前筛选：0题'), findsOneWidget);
    await openDrawer(tester);
    await choose(tester, '2022年');
    await closeDrawer(tester);
    expect(find.text('当前筛选：1题'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
