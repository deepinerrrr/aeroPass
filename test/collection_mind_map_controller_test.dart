import 'package:flutter_test/flutter_test.dart';
import 'package:license_app/data/models/question_model.dart';
import 'package:license_app/modules/tools/collection_mind_map_controller.dart';

void main() {
  group('CollectionMindMapController.parseMindMap', () {
    test('parses the constrained AI JSON response into visible branches', () {
      final map = CollectionMindMapController.parseMindMap('''```json
{"title":"管制地带边界","nodes":[{"title":"距离与高度","children":["20~30km 对应 750m","重点辨析高度条件"]},{"title":"圆心半径","children":["B、C 类圆心 10km"]}]}
```''', fallbackTitle: '测试合集');

      expect(map, isNotNull);
      expect(map!.title, '管制地带边界');
      expect(map.branches, hasLength(2));
      expect(map.branches.first.children, contains('20~30km 对应 750m'));
    });

    test('rejects non-JSON AI output so the UI can offer retry', () {
      final map = CollectionMindMapController.parseMindMap(
        '下面是导图：距离、高度、半径',
        fallbackTitle: '测试合集',
      );

      expect(map, isNull);
    });

    test('keeps the map concise and removes non-knowledge sections', () {
      final map = CollectionMindMapController.parseMindMap('''
{"title":"核心知识","nodes":[
{"title":"定义","children":["定义一","定义二","冗余内容"]},
{"title":"易错点","children":["常见错误"]},
{"title":"规则","children":["规则一"]},
{"title":"条件","children":["条件一"]},
{"title":"数值","children":["数值一"]},
{"title":"结论","children":["结论一"]},
{"title":"额外分支","children":["额外内容"]}
]}
''', fallbackTitle: '测试合集');

      expect(map, isNotNull);
      expect(map!.branches, hasLength(5));
      expect(map.branches.first.children, ['定义一', '定义二']);
      expect(
        map.branches.map((branch) => branch.title),
        isNot(contains('易错点')),
      );
    });
  });

  test(
    'AI input includes type and content but excludes question ID metadata',
    () {
      final context = CollectionMindMapController.buildQuestionContext('测试合集', [
        Question(
          questionId: 'Q-SECRET-42',
          content: '机场标高是指机场可用着陆地带内的最高点标高。',
          answer: 'A',
          optionA: '正确',
          optionB: '错误',
          type: 'judge',
        ),
      ]);

      expect(context, contains('题型：判断题'));
      expect(context, contains('题干：机场标高'));
      expect(context, isNot(contains('Q-SECRET-42')));
    },
  );
}
