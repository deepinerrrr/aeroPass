import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:license_app/data/models/question_model.dart';
import 'package:license_app/modules/tools/collection_mind_map_selection_view.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('导图选题页完整显示题干和题型并支持全选', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const fullStem =
        '这是一个需要完整显示的很长题干，用于确认选题列表不会使用省略号截断题目内容，并且用户可以在生成导图前读完全部题干。';
    final questions = [
      Question(questionId: '1', content: fullStem, answer: 'A', type: 'judge'),
      Question(questionId: '2', content: '单选题题干', answer: 'B', type: 'single'),
    ];

    await tester.pumpWidget(
      GetMaterialApp(
        home: CollectionMindMapSelectionView(
          keyword: '测试合集',
          questions: questions,
        ),
      ),
    );

    expect(find.text(fullStem), findsOneWidget);
    expect(find.text('判断题'), findsOneWidget);
    expect(find.text('单选题'), findsOneWidget);
    expect(find.text('已选择 2 / 2 道题目'), findsOneWidget);
    expect(find.text('取消全选'), findsOneWidget);
    expect(find.textContaining('题目编号不会发送'), findsOneWidget);

    await tester.tap(find.text('取消全选'));
    await tester.pump();

    expect(find.text('已选择 0 / 2 道题目'), findsOneWidget);
    expect(find.text('全选'), findsOneWidget);
    final generateButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '生成思维导图（0）'),
    );
    expect(generateButton.onPressed, isNull);
  });
}
