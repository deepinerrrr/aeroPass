import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:license_app/data/models/question_model.dart';
import 'package:license_app/modules/tools/collection_controller.dart';
import 'package:license_app/modules/tools/collection_list_view.dart';

class _FakeCollectionController extends CollectionController {
  bool? requestedAnswer;

  @override
  Future<void> loadCollections() async {
    correctJudgeCount.value = 772;
    wrongJudgeCount.value = 800;
    collections.clear();
    isLoading.value = false;
  }

  @override
  Future<void> createJudgeCollection(bool answerIsCorrect) async {
    requestedAnswer = answerIsCorrect;
  }
}

class _FakeDeleteCollectionController extends CollectionController {
  String? deletedKeyword;

  @override
  Future<void> loadCollections() async {
    collections.assign(CollectionInfo(keyword: '待删除合集', questionCount: 3));
    isLoading.value = false;
  }

  @override
  Future<bool> deleteCollection(String keyword) async {
    deletedKeyword = keyword;
    collections.clear();
    return true;
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('合集管理可分别创建答案正确和答案错误的判断题合集', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _FakeCollectionController();
    Get.put<CollectionController>(controller);

    await tester.pumpWidget(const GetMaterialApp(home: CollectionListView()));
    await tester.pump();

    expect(find.text('默认题库判断题'), findsOneWidget);
    expect(find.text('答案正确'), findsOneWidget);
    expect(find.text('答案错误'), findsOneWidget);
    expect(find.text('默认题库共 772 道'), findsOneWidget);
    expect(find.text('默认题库共 800 道'), findsOneWidget);

    await tester.tap(find.text('创建合集').first);
    await tester.pump();
    expect(controller.requestedAnswer, isTrue);

    await tester.tap(find.text('创建合集').last);
    await tester.pump();
    expect(controller.requestedAnswer, isFalse);
  });

  testWidgets('合集列表删除前说明保留原题并要求确认', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _FakeDeleteCollectionController();
    Get.put<CollectionController>(controller);

    await tester.pumpWidget(const GetMaterialApp(home: CollectionListView()));
    await tester.pump();

    await tester.tap(find.byTooltip('删除合集'));
    await tester.pumpAndSettle();
    expect(find.text('删除合集？'), findsOneWidget);
    expect(find.textContaining('题库原题、笔记和学习记录不会被删除'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(controller.deletedKeyword, '待删除合集');
  });
}
