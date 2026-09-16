import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_app/modules/common/current_question_grid.dart';

void main() {
  testWidgets('答题卡打开后自动定位到当前题所在行', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 320,
            child: CurrentQuestionGrid(
              controller: controller,
              currentIndex: 120,
              itemCount: 180,
              itemBuilder: (context, index) => Text('${index + 1}'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(controller.offset, greaterThan(0));
    expect(
      controller.offset,
      lessThanOrEqualTo(controller.position.maxScrollExtent),
    );
  });
}
